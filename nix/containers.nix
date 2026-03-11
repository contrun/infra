{
  pkgs,
  packages,
  zotero-plugins,
}:
let
  inherit (packages) getSecret;
in
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
      rclonePort = 5572;
      rcloneUrl = "rclone";
      nginxConfig =
        let
          services =
            let
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
              mkCommand =
                name: attrs:
                let
                  inherit (attrs) port url;
                  checkRcdOnlineCommand = ''
                    /bin/curl --retry 300 --retry-delay 0.1 --retry-connrefused http://127.0.0.1:${builtins.toString rclonePort}/${rcloneUrl}
                  '';
                  rcCommand = "/bin/rclone rc --url http://127.0.0.1:${builtins.toString rclonePort}/${rcloneUrl}";
                  commands =
                    if name == "s3" then
                      [
                        checkRcdOnlineCommand
                        ''
                          ${rcCommand} serve/start vfs_cache_mode=full type=s3 fs=root: addr=:${builtins.toString port} baseurl=${url} auth_key="$RCLONE_RC_USER,$RCLONE_RC_PASS"
                        ''
                      ]
                    else if name == "webdav" then
                      [
                        checkRcdOnlineCommand
                        ''
                          ${rcCommand} serve/start vfs_cache_mode=full type=webdav fs=root: addr=:${builtins.toString port} baseurl=${url} realm=${name} user="$RCLONE_RC_USER" pass="$RCLONE_RC_PASS"
                        ''
                      ]
                    else if name == "restic" then
                      [
                        checkRcdOnlineCommand
                        ''
                          ${rcCommand} serve/start vfs_cache_mode=full type=restic fs=restic: addr=:${builtins.toString port} baseurl=${url} realm=${name} user="$RCLONE_RC_USER" pass="$RCLONE_RC_PASS"
                        ''
                      ]
                    else if name == "public" then
                      [
                        checkRcdOnlineCommand
                        ''
                          ${rcCommand} serve/start vfs_cache_mode=full type=http fs=public: addr=:${builtins.toString port} baseurl=${url}
                        ''
                      ]
                    else
                      builtins.throw "Unknown service ${name}";
                  command = with lib.strings; concatMapStringsSep " && " (command: trim command) commands;
                in
                attrs // { inherit command; };
              services = builtins.mapAttrs mkCommand (builtins.listToAttrs list);
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
          mkUpstream = name: port: ''
            upstream ${name} {
              server 127.0.0.1:${builtins.toString port};
            }
          '';
          upstreams = lib.strings.concatMapStringsSep "\n" (x: mkUpstream x.name x.port) serviceList;
          mkLocation =
            name: url: command:
            let
              access =
                if command == null then
                  ""
                else
                  ''
                    access_by_lua_block {
                        local ngx = require "ngx"

                        local shared = ngx.shared.server_info
                        local key = "${name}_initializing_time"
                        local initializing_time = shared:get(key)

                        -- Even if we have tried to initialize the handler by running the command,
                        -- we may still unable to serve other requests that require the command to
                        -- be successfully finished. Ideally we should have a shared semaphore,
                        -- and make the first request handler acquire and release the semaphore,
                        -- while keep other request handlers to wait for its release.
                        -- This will make the code more complicated. But our commands are idempotent,
                        -- which is guaranteed by the os wouldn't let any other process to listen to
                        -- the same port twice. So we can just run the command many times.
                        if not initializing_time then
                            ngx.log(ngx.INFO, "Trying to initialize ${name}")
                            local ngx_pipe = require "ngx.pipe"
                            -- Run command only if local worker has not ran the command yet.
                            local opts = {
                                merge_stderr = true,
                                buffer_size = 256,
                                environ = {"RCLONE_RC_USER=" .. os.getenv("RCLONE_RC_USER"), "RCLONE_RC_PASS=" .. os.getenv("RCLONE_RC_PASS"), "RCLONE_PASSWORD_COMMAND=" .. os.getenv("RCLONE_PASSWORD_COMMAND")}
                            }
                            local proc, err = ngx_pipe.spawn(${lib.strings.escapeShellArg command}, opts)
                            if not proc then
                                ngx.log(ngx.ERR, "Failed to run command ${name}: ", err)
                                ngx.say("An internal error happened")
                                return ngx.exit(500)
                            end
                            local waiting_time_seconds = 60
                            local waiting_time_mili_seconds = waiting_time_seconds * 1000
                            proc:set_timeouts(waiting_time_mili_seconds)
                            local ok, reason, status = proc:wait()
                            -- It is OK that the command fails because, as explained above,
                            -- we may run the command a few time. All that we want is
                            -- the command exits.
                            if not ok then
                                ngx.log(ngx.ERR, "Failed to wait for process of ${name}: ", reason, status)
                            end
                            ngx.log(ngx.INFO, "Successfully initialized ${name}")
                            local now = ngx.now()
                            shared:set(key, now)
                        end
                    }
                  '';
            in
            ''
              location /${url} {
                  ${access}
                  proxy_pass http://${name};
              }
            '';
          locations = lib.strings.concatMapStringsSep "\n" (x: mkLocation x.name x.url x.command) serviceList;
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
                client_max_body_size 0;
                tcp_nopush on;
                tcp_nodelay on;
                keepalive_timeout 65;
                access_log /dev/stdout;

                ${upstreams}

                lua_shared_dict server_info 12k;

                init_by_lua_block {
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
      getSecretPath = lib.getExe getSecret;
      entrypointName = "container-entrypoint";
      entrypoint = writeShellApplication {
        name = entrypointName;
        text = ''
          set -euo pipefail
          export RCLONE_CONFIG="/tmp/rclone.conf"
          ${getSecretPath} f9876fcd-2545-43d4-be09-b401012a679a > "$RCLONE_CONFIG"
          export RCLONE_PASSWORD_COMMAND="${getSecretPath} 3b3ca859-97eb-486b-829b-b20a010a7747"
          RCLONE_RC_USER="$(${getSecretPath} 4615a562-2a50-4a71-adc5-b4010124ddeb)"
          RCLONE_RC_PASS="$(${getSecretPath} f360f175-7e38-4ac8-9e53-b40101250a36)"
          export RCLONE_RC_USER RCLONE_RC_PASS
          rclone rcd --cache-dir /data/cache --rc-addr :${builtins.toString rclonePort} --rc-baseurl ${rcloneUrl} --rc-web-gui --rc-web-gui-no-open-browser &
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

  caddy =
    with pkgs;
    let
      caddy = packages.mycaddy;
      entrypoint = writeShellScriptBin {
        name = "container-entrypoint";
        text = ''
          #!/bin/sh
          set -eu

          fetchConfig() {
            config="$(${lib.getExe getSecret} 2d60eed9-6d84-4a61-a3b2-b406008fcbde)" || return 1
            printf '%s' "$config" > ./Caddyfile
          }
          if [ -f ./Caddyfile ]; then
            caddy run --config ./Caddyfile &
            if fetchConfig; then
              caddy reload --config ./Caddyfile
            fi
          else
            fetchConfig
            caddy run --config ./Caddyfile &
          fi
          wait -n
        '';
      };
    in
    dockerTools.buildLayeredImage {
      name = "caddy";
      tag = "latest";
      maxLayers = 10;
      contents = with pkgs.dockerTools; [
        usrBinEnv
        binSh
        caCertificates
        fakeNss

        caddy
        entrypoint
      ];

      config = {
        Volumes = {
          "/data" = { };
        };
        WorkingDir = "/data";
        Entrypoint = [
          "${lib.getExe entrypoint}"
        ];
        Env = [
          # $PATH seems to be unset in fly.io
          "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        ];
      };
    };

  zotero =
    with pkgs;
    let
      zotero = packages.zotero;
      zoteroHome = "/home/e";
      htpasswdPath = "/tmp/.htpasswd";
      zoteroVersion = with builtins; elemAt (splitVersion zotero.version) 0;
      enabledPlugins = [
        "debug-bridge@iris-advies.com"
        "zoplicate@chenglongma.com"
      ];
      pluginPaths =
        with builtins;
        let
          zoteroPlugins = fromJSON (readFile "${zotero-plugins}/dist/plugins.json");
          releases = lib.flatten (map (x: x.releases) zoteroPlugins);
          goodReleases = filter (
            x:
            (x.targetZoteroVersion == zoteroVersion || x.id == "debug-bridge@iris-advies.com")
            && (builtins.elem x.id enabledPlugins)
          ) releases;
        in
        listToAttrs (
          builtins.map (
            x:
            let
              paths = split "gh-pages" x.xpiDownloadUrl.gitee;
              path = elemAt paths ((length paths) - 1);
            in
            {
              name = x.id;
              value = "${zotero-plugins}${path}";
            }
          ) goodReleases
        );
      plugins = pkgs.runCommand "zotero-plugins" { } ''
        mkdir -p $out/lib/distribution/
        cd $out/lib/distribution/
        ${lib.strings.concatMapAttrsStringSep "\n" (plugin: path: ''
          cp ${path} "${plugin}.xpi"
        '') pluginPaths}
      '';
      nginxConfig =
        let
          config = ''
            daemon off;
            user nobody nobody;
            error_log stderr info;
            pid /dev/null;

            events {}

            http {
                sendfile on;
                client_max_body_size 0;
                tcp_nopush on;
                tcp_nodelay on;
                keepalive_timeout 65;
                access_log /dev/stdout;

                server {
                    listen *:24119;
                    server_name _;
                    location / {
                        proxy_pass http://127.0.0.1:23119;
                        auth_basic "Administrator’s Area";
                        auth_basic_user_file ${htpasswdPath};
                    }
                }
            }
          '';
        in
        writers.writeNginxConfig "nginx.conf" config;
      userjs = ''
        user_pref("app.update.auto", false);
        user_pref("app.update.enabled", false);
        user_pref("browser.displayedE10SNotice", 4);
        user_pref("browser.dom.window.dump.enabled", true);
        user_pref("browser.download.manager.showWhenStarting", false);
        user_pref("browser.EULA.3.accepted", true);
        user_pref("browser.EULA.override", true);
        user_pref("browser.laterrun.enabled", false);
        user_pref("browser.link.open_external", 2);
        user_pref("browser.link.open_newwindow", 2);
        user_pref("browser.newtabpage.enabled", false);
        user_pref("browser.newtab.url", "about:blank");
        user_pref("browser.offline", false);
        user_pref("browser.reader.detectedFirstArticle", true);
        user_pref("browser.safebrowsing.enabled", false);
        user_pref("browser.safebrowsing.malware.enabled", false);
        user_pref("browser.search.update", false);
        user_pref("browser.selfsupport.url", "");
        user_pref("browser.sessionstore.resume_from_crash", false);
        user_pref("browser.shell.checkDefaultBrowser", false);
        user_pref("browser.startup.homepage", "about:blank");
        user_pref("browser.startup.homepage_override.mstone", "ignore");
        user_pref("browser.startup.page", 0);
        user_pref("browser.tabs.warnOnClose", false);
        user_pref("browser.tabs.warnOnOpen", false);
        user_pref("browser.usedOnWindows10.introURL", "about:blank");
        user_pref("datareporting.healthreport.logging.consoleEnabled", false);
        user_pref("datareporting.healthreport.service.enabled", false);
        user_pref("datareporting.healthreport.service.firstRun", false);
        user_pref("datareporting.healthreport.uploadEnabled", false);
        user_pref("datareporting.policy.dataSubmissionEnabled", false);
        user_pref("datareporting.policy.dataSubmissionPolicyAccepted", false);
        user_pref("datareporting.policy.firstRunURL", "");
        user_pref("devtools.browserconsole.contentMessages", true);
        user_pref("devtools.chrome.enabled", true);
        user_pref("devtools.debugger.prompt-connection", false);
        user_pref("devtools.debugger.remote-enabled", true);
        user_pref("devtools.errorconsole.enabled", true);
        user_pref("devtools.source-map.locations.enabled", true);
        user_pref("dom.disable_open_during_load", false);
        user_pref("dom.max_chrome_script_run_time", 0);
        user_pref("dom.max_script_run_time", 0);
        user_pref("dom.report_all_js_exceptions", true);
        user_pref("extensions.blocklist.enabled", false);
        user_pref("extensions.blocklist.pingCountVersion", -1);
        user_pref("extensions.checkCompatibility.nightly", false);
        user_pref("extensions.enabledScopes", 15);
        user_pref("extensions.getAddons.cache.enabled", false);
        user_pref("extensions.logging.enabled", true);
        user_pref("extensions.update.enabled", false);
        user_pref("extensions.update.notifyUser", false);
        user_pref("extensions.zotero.automaticScraperUpdates", true);
        user_pref("extensions.zotero.debug-bridge.token", "def");
        user_pref("extensions.zotero.debug.log", true);
        user_pref("extensions.zotero.debug.store", true);
        user_pref("extensions.zotero.debug.time", true);
        user_pref("extensions.zotero.firstRun2", false);
        user_pref("extensions.zotero.firstRunGuidance", false);
        user_pref("extensions.zotero.firstRunGuidanceShown.z7Banner", false);
        user_pref("extensions.zotero.httpServer.localAPI.enabled", true);
        user_pref("extensions.zoteroMacWordIntegration.installed", true);
        user_pref("extensions.zotero.reportTranslationFailure", false);
        user_pref("javascript.enabled", true);
        user_pref("javascript.options.showInConsole", true);
        user_pref("network.captive-portal-service.enabled", false);
        user_pref("network.http.phishy-userpass-length", 255);
        user_pref("network.manage-offline-status", false);
        user_pref("offline-apps.allow_by_default", true);
        user_pref("prompts.tab_modal.enabled", false);
        user_pref("security.csp.enable", false);
        user_pref("security.fileuri.origin_policy", 3);
        user_pref("security.fileuri.strict_origin_policy", false);
        user_pref("signon.rememberSignons", false);
        user_pref("startup.homepage_welcome_url", "about:blank");
        user_pref("startup.homepage_welcome_url.additional", "about:blank");
        user_pref("toolkit.networkmanager.disable", true);
        user_pref("toolkit.telemetry.enabled", false);
        user_pref("toolkit.telemetry.prompted", 2);
        user_pref("toolkit.telemetry.rejected", true);
        user_pref("urlclassifier.updateinterval", 172800);
        user_pref("webdriver_accept_untrusted_certs", true);
        user_pref("webdriver_assume_untrusted_issuer", true);
        user_pref("webdriver_enable_native_events", true);
        user_pref("xpinstall.enabled", true);
        user_pref("xpinstall.signatures.required", false);
        user_pref("xpinstall.whitelist.required", false);
      '';
      # Username: user, password: xC7hWHAkh7dcQeK94Zq7WjgY
      htpasswd = ''
        user:$apr1$9YuHKers$6vgXSay0To.p4f1CuOB9//
      '';
      entrypoint = writeShellScriptBin "container-entrypoint" ''
        #!/bin/sh
        set -eu
        if ! [ -d .zotero ]; then
          zotero --headless --createprofile managed
          cd .zotero/zotero/*.managed
          if ! [ -d extensions ]; then
            mkdir -p extensions
            cp /lib/distribution/*.xpi extensions
          fi
          [ -f user.js ] || cat > user.js <<EOF
          ${userjs}
        EOF
        fi
        if [ -n "''${HTPASSWD:-}" ]; then
          echo "''${HTPASSWD:-}" > ${htpasswdPath}
        else
          cat > ${htpasswdPath} <<-"EOF"
        ${htpasswd}
        EOF
        fi
        zotero --headless &
        curl --retry 300 --retry-delay 0.1 --retry-connrefused http://127.0.0.1:23119
        nginx -c "${nginxConfig}" &
        wait -n
      '';
    in
    dockerTools.buildLayeredImage {
      name = "zotero";
      tag = "latest";
      maxLayers = 10;
      contents = with pkgs.dockerTools; [
        usrBinEnv
        binSh
        caCertificates

        tini
        coreutils
        curl
        rsync
        nginx
        zotero
        plugins

        entrypoint
      ];

      extraCommands = ''
        mkdir -p -m 1777 ./tmp
      '';

      enableFakechroot = true;
      # We simulate the host paths and host environment so that we can copy existing zotero files and
      # run the container directly. This is required because certain things are hard coded with home directory path.
      # E.g. the path of Zotero folder is written to prefs.js as $HOME/Zotero.
      # With the container image below. I can just copy the files with
      # rsync -avz --progress -h --recursive --exclude='*.bak' --include='Zotero' --exclude=Zotero/storage --include='Zotero/**' --include='.zotero' --include='.zotero/**' --exclude='**' ~/ ~/.local/cache/podman-zotero-volume/
      # The run the container with
      # podman run -it --userns=keep-id --rm --name zotero -v ~/.local/cache/podman-zotero-volume:/home/e -p 24119:24119 localhost/zotero
      # We can also use rsync to sync local zotero files to a fly machine.
      # 1. Issue a ssh certificate to log into fly machine, we can save it to id_fly.io
      # flyctl ssh issue
      # 2. Forward local traffic to remote machine
      # flyctl proxy 10022:22
      # Use rsync to sync local files to remote
      # 3. rsync -e "ssh -p 10022 -i $HOME/.ssh/id_fly.io" --chown 1000:100 -avz --progress -h --recursive --exclude='*.bak' --include='Zotero' --exclude=Zotero/storage --include='Zotero/**' --include='.zotero' --include='.zotero/**' --exclude='**' ~/ root@127.0.0.1:/home/e/
      # We can also restore the zotero files with
      # rsync -e "ssh -p 10022 -i $HOME/.ssh/id_fly.io" -avz --progress -h --recursive root@127.0.0.1:/home/e/ ~/.local/cache/zotero/
      # We may need to update the zotero preferences after a while because we change the preferences locally.
      # rsync -e "ssh -p 10022 -i $HOME/.ssh/id_fly.io" --chown 1000:100 -avz --progress -h ~/.zotero/ root@127.0.0.1:/home/e/.zotero/
      fakeRootCommands = ''
        ${dockerTools.shadowSetup}
        groupadd -r -g 100 users
        useradd -r -g 100 -u 1000 --home-dir ${zoteroHome} --create-home e
      '';

      config = {
        User = "1000:100";
        Volumes = {
          "${zoteroHome}" = { };
        };
        ExposedPorts = {
          "24119/tcp" = { };
        };
        WorkingDir = "${zoteroHome}";
        Entrypoint = [
          "tini"
          "--"
        ];
        Cmd = [
          "${lib.getExe entrypoint}"
        ];
        Env = [
          # $PATH seems to be unset in fly.io
          "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        ];
      };
    };

  owntracks =
    with pkgs;
    let
      home = "/data";
      userHtpasswdPath = "/tmp/user.htpasswd";
      adminHtpasswdPath = "/tmp/admin.htpasswd";
      # Username: user, password: xC7hWHAkh7dcQeK94Zq7WjgY
      defaultHtpasswd = ''
        user:$apr1$9YuHKers$6vgXSay0To.p4f1CuOB9//
      '';
      nginxConfig =
        let
          config = ''
            daemon off;
            error_log stderr info;
            pid /dev/null;

            events {}


            http {
                sendfile on;
                client_max_body_size 0;
                tcp_nopush on;
                tcp_nodelay on;
                keepalive_timeout 65;
                access_log /dev/stdout;

                upstream recorder {
                    server 127.0.0.1:8083;
                }

                server {
                    listen *:8080;
                    server_name _;

                    # OwnTracks Recorder Views (requires /view, /static, /utils)
                    location /view/ {
                        proxy_pass http://recorder;
                        proxy_http_version 1.1;
                        proxy_set_header Host $host;
                        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                        proxy_set_header X-Real-IP $remote_addr;
                    }
                    location /static/ {
                        proxy_pass http://recorder;
                        proxy_http_version 1.1;
                        proxy_set_header Host $host;
                        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                        proxy_set_header X-Real-IP $remote_addr;
                    }
                    location /utils/ {
                        proxy_pass http://recorder;
                        proxy_http_version 1.1;
                        proxy_set_header Host $host;
                        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                        proxy_set_header X-Real-IP $remote_addr;
                    }
                
                    # HTTP Mode
                    location /pub {
                        auth_basic "User’s Area";
                        auth_basic_user_file ${userHtpasswdPath};
                        proxy_pass http://recorder;
                        proxy_http_version 1.1;
                        proxy_set_header Host $host;
                        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                        proxy_set_header X-Real-IP $remote_addr;
                    }

                    location /ws {
                        auth_basic "Administrator’s Area";
                        auth_basic_user_file ${adminHtpasswdPath};
                        proxy_pass http://recorder;
                        proxy_set_header Upgrade $http_upgrade;
                        proxy_set_header Connection "upgrade";
                        proxy_http_version 1.1;
                        proxy_set_header Host $host;
                        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                        proxy_set_header X-Real-IP $remote_addr;
                    }

                    location / {
                        auth_basic "Administrator’s Area";
                        auth_basic_user_file ${adminHtpasswdPath};
                        proxy_pass http://recorder;
                        proxy_http_version 1.1;
                        proxy_set_header Host $host;
                        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
                        proxy_set_header X-Real-IP $remote_addr;
                    }
                }
            }
          '';
        in
        writers.writeNginxConfig "nginx.conf" config;
      entrypoint = writeShellScriptBin "container-entrypoint" ''
        #!/bin/sh
        set -eu
        if [ -n "''${USER_HTPASSWD:-}" ]; then
          echo "''${USER_HTPASSWD:-}" > ${userHtpasswdPath}
        else
          cat > ${userHtpasswdPath} <<-"EOF"
        ${defaultHtpasswd}
        EOF
        fi
        if [ -n "''${ADMIN_HTPASSWD:-}" ]; then
          echo "''${ADMIN_HTPASSWD:-}" > ${adminHtpasswdPath}
        else
          cat > ${adminHtpasswdPath} <<-"EOF"
        ${defaultHtpasswd}
        EOF
        fi
        ot-recorder --port 0 --storage ./data --http-host 127.0.0.1 --http-port 8083 &
        curl --retry 300 --retry-delay 0.1 --retry-connrefused http://127.0.0.1:8083
        nginx -c "${nginxConfig}" &
        wait -n
      '';
    in
    dockerTools.buildLayeredImage {
      name = "owntracks";
      tag = "latest";
      maxLayers = 10;
      contents = with pkgs.dockerTools; [
        usrBinEnv
        binSh
        caCertificates

        tini
        coreutils
        curl
        nginx
        owntracks-recorder

        entrypoint
      ];

      extraCommands = ''
        mkdir -p -m 1777 ./tmp
      '';

      enableFakechroot = true;
      fakeRootCommands = ''
        ${dockerTools.shadowSetup}
        groupadd -r -g 100 users
        useradd -r -g 100 -u 1000 --home-dir ${home} --create-home e
      '';

      config = {
        User = "1000:100";
        Volumes = {
          "${home}" = { };
        };
        ExposedPorts = {
          "8080/tcp" = { };
        };
        WorkingDir = "${home}";
        Entrypoint = [
          "tini"
          "--"
        ];
        Cmd = [
          "${lib.getExe entrypoint}"
        ];
        Env = [
          # $PATH seems to be unset in fly.io
          "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        ];
      };
    };
}
