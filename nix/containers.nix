{ pkgs }:
{
  texlive =
    with pkgs;
    dockerTools.buildImage rec {
      name = "texlive-full";
      tag = "latest";
      copyToRoot = buildEnv {
        inherit name;
        paths = [
          (texlive.combine { inherit (texlive) scheme-full; })
          adoptopenjdk-bin
          font-awesome_4
          font-awesome_5
          nerdfonts
          pdftk
          bash
          gnugrep
          gnused
          coreutils
          gnumake
        ];
      };
      config.Cmd = [ "/bin/sh" ];
    };

  rclone =
    with pkgs;
    let
      exposedPort = 10000;
      services =
        let
          rclonePort = 5572;
          rcloneUrl = "rclone";
          list =
            lib.imap1
              (x: name: {
                name = name;
                value = {
                  name = name;
                  port = rclonePort + x;
                  url = name;
                };
              })
              [
                "s3"
                "webdav"
                "restic"
                "public"
              ];
          appendCommand =
            name: attrs:
            let
              inherit (attrs) port url;
              rcCommand = "/bin/rclone rc --url http://127.0.0.1:${builtins.toString rclonePort}/${rcloneUrl}";
              command =
                if name == "s3" then
                  ''
                    ${rcCommand} serve/start vfs_cache_mode=full type=s3 fs=root: addr=:${builtins.toString port} baseurl=${url} auth_key="$RCLONE_RC_USER,$RCLONE_RC_PASS"
                  ''
                else if name == "webdav" then
                  ''
                    ${rcCommand} serve/start vfs_cache_mode=full type=webdav fs=root: addr=:${builtins.toString port} baseurl=${url} realm=${name} user="$RCLONE_RC_USER" pass="$RCLONE_RC_PASS"
                  ''
                else if name == "restic" then
                  ''
                    ${rcCommand} serve/start vfs_cache_mode=full type=restic fs=restic: addr=:${builtins.toString port} baseurl=${url} realm=${name} user="$RCLONE_RC_USER" pass="$RCLONE_RC_PASS"
                  ''
                else if name == "public" then
                  ''
                    ${rcCommand} serve/start vfs_cache_mode=full type=http fs=public: addr=:${builtins.toString port} baseurl=${url}
                  ''
                else
                  builtins.throw "Unknown service ${name}";
            in
            attrs // { inherit command; };
          services = builtins.mapAttrs appendCommand (builtins.listToAttrs list);
        in
        {
          "rclone" = {
            name = "rclone";
            port = rclonePort;
            url = rcloneUrl;
            command = null;
          };
        }
        // services;

      serviceList = builtins.attrValues services;
      nginxConfig =
        let
          mkUpstream = name: port: command: ''
            upstream ${name} {
                balancer_by_lua_block {
                    local balancer = require "ngx.balancer"
                    local command = ${
                      if command == null then "nil" else lib.strings.escapeShellArg (lib.strings.trim command)
                    };

                    if command ~= nil then
                        local ngx = require "ngx"
                        local ngx_pipe = require "ngx.pipe"

                        local shared = ngx.shared.server_info
                        local key = "${name}_initializing_time"
                        local now = ngx.now()
                        local initializing_time = shared:get(key)
                        local waiting_time = 60

                        -- Even if we have tried to initialize the handler by running the command,
                        -- we may still unable to serve other requests that require the command to
                        -- be successfully finished. Ideally we should have a shared semaphore,
                        -- and make the first request handler acquire and release the semaphore,
                        -- while keep other request handlers to wait for its release.
                        -- This will make the code more complicated. But our commands are idempotent,
                        -- which is guaranteed by the os wouldn't let any other process to listen to
                        -- the same port twice. So we can just run the command many times.
                        -- One more problem is that we don't want the commands to run indefinitely,
                        -- because they may have some permanant failure. So we only run the commands
                        -- for a short period of time (i.e. not after the waiting time here).
                        if not initializing_time or now - initializing_time < waiting_time then
                            -- Run command only if local worker has not ran the command yet.
                            local is_first_run = ngx.ctx.time_of_starting_command == nil
                            if is_first_run then
                                ngx.ctx.time_of_starting_command = now
                                if not initializing_time then
                                    shared:set(key, now)
                                end
                                local opts = {
                                    merge_stderr = true,
                                    buffer_size = 256,
                                    environ = {"RCLONE_RC_USER=" .. os.getenv("RCLONE_RC_USER"), "RCLONE_RC_PASS=" .. os.getenv("RCLONE_RC_PASS"), "RCLONE_PASSWORD_COMMAND=" .. os.getenv("RCLONE_PASSWORD_COMMAND")}
                                }
                                local proc, err = ngx_pipe.spawn(command, opts)
                                if not proc then
                                    ngx.log(ngx.ERR, "Failed to initialized ${name}: ", err)
                                    ngx.say("An internal error happened")
                                    return ngx.exit(500)
                                else
                                    ngx.log(ngx.INFO, "Successfully initialized ${name}")
                                end
                            end
                            local running_time = now - ngx.ctx.time_of_starting_command
                            if running_time < 60 then
                                local ok, err = balancer.set_more_tries(1)
                                if not ok then
                                    ngx.log(ngx.ERR, "Failed to set more tries: ", err)
                                end
                            else
                                ngx.log(ngx.ERR, "Command does not seem to succeed after 60 seconds: ", command)
                            end
                        end
                    end
                    local host = "127.0.0.1"
                    local port = ${builtins.toString port}

                    local ok, err = balancer.set_current_peer(host, port)
                    if not ok then
                        ngx.log(ngx.ERR, "Failed to set the current peer: ", err)
                        return ngx.exit(500)
                    end
                }
            }
          '';
          upstreams = lib.strings.concatMapStringsSep "\n" (
            x: mkUpstream x.name x.port x.command
          ) serviceList;
          mkLocation = name: url: ''
            location /${url} {
                proxy_pass http://${name};
                proxy_next_upstream error timeout invalid_header http_502;
            }
          '';
          locations = lib.strings.concatMapStringsSep "\n" (x: mkLocation x.name x.url) serviceList;
          config = ''
            daemon off;
            user nobody nobody;
            error_log stderr info;
            pid /dev/null;
            env RCLONE_RC_USER;
            env RCLONE_RC_PASS;
            env RCLONE_PASSWORD_COMMAND;

            events {}

            http {
                sendfile on;
                tcp_nopush on;
                tcp_nodelay on;
                keepalive_timeout 65;
                access_log /dev/stdout;

                ${upstreams}

                # Define a shared dictionary to store the start time
                lua_shared_dict server_info 12k;

                init_by_lua_block {
                    -- Capture the start time globally once
                    local shared = ngx.shared.server_info
                    shared:set("start_time", ngx.now())
                }

                server {
                    listen *:${builtins.toString exposedPort};
                    server_name _;

                    location /uptime {
                        content_by_lua_block {
                            local shared = ngx.shared.server_info
                            local start_time = shared:get("start_time")
                            local uptime = ngx.now() - start_time

                            ngx.say(string.format("NGINX Uptime: %.2f seconds", uptime))
                        }
                    }

                    ${locations}
                }
            }
          '';
        in
        writers.writeNginxConfig "nginx.conf" config;
      getSecretName = "get-secret";
      getSecret = writeShellApplication {
        name = getSecretName;
        text = ''
          set -euo pipefail
          bws secret get "$1" | jq -r '.value'
        '';
        runtimeInputs = [
          bws
          jq
        ];
      };
      getSecretCommand = "/bin/${getSecretName}";
      getPasswordName = "get-password";
      getPassword = writeShellApplication {
        name = getPasswordName;
        text = ''
          set -euo pipefail
          ${getSecretName} 3b3ca859-97eb-486b-829b-b20a010a7747
        '';
        runtimeInputs = [
          getSecret
        ];
      };
      passwordCommand = "/bin/${getPasswordName}";
      entrypointName = "container-entrypoint";
      entrypoint = writeShellApplication {
        name = entrypointName;
        text = ''
          set -euo pipefail
          export RCLONE_CONFIG="/tmp/rclone.conf"
          ${getSecretCommand} f9876fcd-2545-43d4-be09-b401012a679a > "$RCLONE_CONFIG"
          export RCLONE_PASSWORD_COMMAND="${passwordCommand}"
          RCLONE_RC_USER="$(${getSecretCommand} 4615a562-2a50-4a71-adc5-b4010124ddeb)"
          RCLONE_RC_PASS="$(${getSecretCommand} f360f175-7e38-4ac8-9e53-b40101250a36)"
          export RCLONE_RC_USER RCLONE_RC_PASS
          rclone rcd --cache-dir /data/cache --rc-addr :${builtins.toString services.rclone.port} --rc-baseurl ${services.rclone.url} --rc-web-gui --rc-web-gui-no-open-browser &
          curl --retry 30 --retry-delay 1 --retry-connrefused http://127.0.0.1:${builtins.toString services.rclone.port}/${services.rclone.url}
          nginx -c "${nginxConfig}" &
          wait -n
        '';
      };
    in
    dockerTools.buildLayeredImage {
      name = "rclone";
      tag = "latest";
      maxLayers = 10;
      contents = with pkgs.dockerTools; [
        usrBinEnv
        binSh
        caCertificates
        fakeNss

        tini

        openresty

        iptables
        procps
        kmod

        coreutils
        findutils
        gnugrep
        gnused
        gawk
        bash

        socat
        rclone
        curl

        getSecret
        getPassword
        entrypoint
      ];

      extraCommands = ''
        mkdir -p -m 1777 ./tmp
      '';

      config = {
        ExposedPorts = {
          "${builtins.toString exposedPort}/tcp" = { };
        };
        WorkingDir = "/data";
        Volumes = {
          "/data" = { };
        };
        Entrypoint = [
          "tini"
          "--"
        ];
        Cmd = [
          "/bin/${entrypointName}"
        ];
        Env = [
          # $PATH seems to be unset in fly.io
          "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        ];
      };
    };

  tailscale =
    with pkgs;
    dockerTools.buildLayeredImage rec {
      name = "tailscale";
      tag = "latest";
      maxLayers = 10;
      contents = with pkgs.dockerTools; [
        usrBinEnv
        binSh
        caCertificates
        fakeNss

        iptables
        procps
        kmod

        coreutils
        findutils
        gnugrep
        gnused
        gawk
        bash

        tailscale
        headscale

        socat
        gost
        caddy
        rclone

        (writeShellApplication {
          name = "container-entrypoint";
          text = ''
            modprobe xt_mark || true

            sysctl net.ipv4.ip_forward=1 || true
            sysctl net.ipv6.conf.all.forwarding=1 || true
            if interface="$(awk '$8 == "00000000" {print}' /proc/net/route | sort --batch-size=1000 -k7 | awk '{print $1; exit}')"; then
                iptables -t nat -A POSTROUTING -o "$interface" -j MASQUERADE || true
                ip6tables -t nat -A POSTROUTING -o "$interface" -j MASQUERADE || true
            else
                iptables -t nat -A POSTROUTING -j MASQUERADE || true
                ip6tables -t nat -A POSTROUTING -j MASQUERADE || true
            fi

            hostname="$HOSTNAME"
            is_fly_io=
            if [[ -v FLY_REGION ]]; then
                is_fly_io=y
                hostname=fly-$FLY_REGION
            fi
            if [[ -n "$is_fly_io" ]]; then
                echo "Running on fly io."
            fi

            declare -a tailscaled_arguments=(tailscaled --verbose=1 --statedir="/data/tailscaled-$hostname")
            if [[ -v TAILSCALE_PORT ]]; then
                tailscaled_arguments+=(--port="$TAILSCALE_PORT")
            fi
            echo Running tailscale "''${tailscaled_arguments[@]}"
            "''${tailscaled_arguments[@]}" &
            sleep 5

            if ! pgrep -f -a tailscaled; then
                exit 1
            fi

            n=0
            until tailscale up --authkey="$TAILSCALE_AUTH_KEY" --hostname="$hostname" --advertise-exit-node; do
                if [[ "$n" -ge 10 ]]; then
                    echo "Failed to bring up tailscale."
                    exit 1
                fi
                n=$((n+1))
                sleep 1
            done

            echo 'Tailscale started. Lets go!'

            wait
          '';
        })
      ];

      config = {
        Volumes = {
          "/data" = { };
        };
        Entrypoint = [
          "/bin/container-entrypoint"
        ];
        Env = [
          # $PATH seems to be unset in fly.io
          "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        ];
      };
    };
}
