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
          initPort = 5572;
          list =
            lib.imap0
              (x: name: {
                name = name;
                value = {
                  name = name;
                  port = initPort + x;
                  url = name;
                };
              })
              [
                "rclone"
                "s3"
                "webdav"
                "restic"
                "files"
                "public"
              ];
        in
        builtins.listToAttrs list;
      serviceList = builtins.attrValues services;
      nginxConfig =
        let
          mkUpstream = name: port: ''
            upstream ${name} {
                balancer_by_lua_block {
                    local balancer = require "ngx.balancer"

                    local shared = ngx.shared.server_info
                    local start_time = shared:get("start_time")
                    local uptime = ngx.now() - start_time

                    -- Upstream may not be ready yet. We want to retry
                    -- if we have not ran for a long time.
                    if uptime < 60 then
                        local ok, err = balancer.set_more_tries(1)
                        if not ok then
                            ngx.log(ngx.ERR, "Failed to set more tries: ", err)
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
          upstreams = lib.strings.concatMapStringsSep "\n" (x: mkUpstream x.name x.port) serviceList;
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
            error_log /dev/stderr info;
            pid /dev/null;

            events {}

            http {
                sendfile on;
                tcp_nopush on;
                tcp_nodelay on;
                keepalive_timeout 65;
                access_log /dev/stdout;

                ${upstreams}

                # Define a shared dictionary to store the start time
                lua_shared_dict server_info 1k;

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
      entrypointName = "container-entrypoint";
      entrypoint = writeShellApplication {
        name = entrypointName;
        text = ''
          set -euo pipefail
          export RCLONE_CONFIG="/tmp/rclone.conf"
          ${getSecretName} f9876fcd-2545-43d4-be09-b401012a679a > "$RCLONE_CONFIG"
          export RCLONE_PASSWORD_COMMAND="${getSecretName} 3b3ca859-97eb-486b-829b-b20a010a7747"
          rclone_user="$(${getSecretName} 4615a562-2a50-4a71-adc5-b4010124ddeb)"
          rclone_pass="$(${getSecretName} f360f175-7e38-4ac8-9e53-b40101250a36)"
          RCLONE_RC_USER="$rclone_user" RCLONE_RC_PASS="$rclone_pass" rclone rcd --cache-dir /data/cache --rc-addr :${builtins.toString services.rclone.port} --rc-baseurl ${services.rclone.url} --rc-web-gui-no-open-browser &
          export rclone_user rclone_pass
          (
            curl --retry 20 --retry-delay 1 --retry-connrefused http://127.0.0.1:${builtins.toString services.rclone.port}/${services.rclone.url}
            rclone rc --user "$rclone_user" --pass "$rclone_pass" --url http://127.0.0.1:${builtins.toString services.rclone.port}/${services.rclone.url} serve/start type=s3 fs=root: addr=:${builtins.toString services.s3.port} baseurl=${services.s3.url} auth_key="$rclone_user,$rclone_pass" _async=true &
            rclone rc --user "$rclone_user" --pass "$rclone_pass" --url http://127.0.0.1:${builtins.toString services.rclone.port}/${services.rclone.url} serve/start type=webdav fs=root: addr=:${builtins.toString services.webdav.port} baseurl=${services.webdav.url} realm=${services.webdav.name} user="$rclone_user" pass="$rclone_pass" _async=true &
            rclone rc --user "$rclone_user" --pass "$rclone_pass" --url http://127.0.0.1:${builtins.toString services.rclone.port}/${services.rclone.url} serve/start type=restic fs=restic: addr=:${builtins.toString services.restic.port} baseurl=${services.restic.url} realm=${services.restic.name} user="$rclone_user" pass="$rclone_pass" _async=true &
            rclone rc --user "$rclone_user" --pass "$rclone_pass" --url http://127.0.0.1:${builtins.toString services.rclone.port}/${services.rclone.url} serve/start type=http fs=root: addr=:${builtins.toString services.files.port} baseurl=${services.files.url} realm=${services.files.name} user="$rclone_user" pass="$rclone_pass" _async=true &
            rclone rc --user "$rclone_user" --pass "$rclone_pass" --url http://127.0.0.1:${builtins.toString services.rclone.port}/${services.rclone.url} serve/start type=http fs=public: addr=:${builtins.toString services.public.port} baseurl=${services.public.url} _async=true &
          )
          unset rclone_user rclone_pass
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
