{
  pkgs,
  packages,
  zotero-plugins,
}:
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
      home = "/data";
      exposedPort = 10000;
      rclonePort = 5572;
      rcloneUrl = "rclone";
      downloadHtpasswd =
        component:
        let
          prefix = "/tmp/rclone.htpasswd";
          htpasswdFile = "${prefix}.${component}";
        in
        {
          inherit htpasswdFile;
          downloadCommand = ''
            /bin/curl -sS --get --create-dirs --output "${htpasswdFile}" -d htpasswd=${component} "$RCLONE_HTPASSWD_URL"
          '';
        };
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
                with (downloadHtpasswd name);
                let
                  inherit (attrs) port url;
                  checkRcdOnlineCommand = ''
                    /bin/curl --retry 300 --retry-delay 0.1 --retry-connrefused http://127.0.0.1:${builtins.toString rclonePort}/${rcloneUrl}
                  '';
                  rcCommand = "/bin/rclone rc --url http://127.0.0.1:${builtins.toString rclonePort}/${rcloneUrl}";
                  commands =
                    if name == "s3" then
                      [
                        downloadCommand
                        checkRcdOnlineCommand
                        ''
                          ${rcCommand} serve/start vfs_cache_mode=full type=s3 fs=root: addr=:${builtins.toString port} baseurl=${url} htpasswd="${htpasswdFile}"
                        ''
                      ]
                    else if name == "webdav" then
                      [
                        downloadCommand
                        checkRcdOnlineCommand
                        ''
                          ${rcCommand} serve/start vfs_cache_mode=full type=webdav fs=root: addr=:${builtins.toString port} baseurl=${url} realm=${name} htpasswd="${htpasswdFile}"
                        ''
                      ]
                    else if name == "restic" then
                      [
                        downloadCommand
                        checkRcdOnlineCommand
                        ''
                          ${rcCommand} serve/start vfs_cache_mode=full type=restic fs=restic: addr=:${builtins.toString port} baseurl=${url} realm=${name} htpasswd="${htpasswdFile}"
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
                                environ = {"RCLONE_RC_USER=" .. os.getenv("RCLONE_RC_USER"), "RCLONE_RC_PASS=" .. os.getenv("RCLONE_RC_PASS"), "RCLONE_HTPASSWD_URL=" .. os.getenv("RCLONE_HTPASSWD_URL")}
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
            env RCLONE_HTPASSWD_URL;
            env RCLONE_RC_USER;
            env RCLONE_RC_PASS;

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
      entrypointName = "container-entrypoint";
      entrypoint = writeShellApplication {
        name = entrypointName;
        text = with (downloadHtpasswd "rcd"); ''
          export RCLONE_CONFIG="/tmp/rclone.conf"
          rclone copyurl "$RCLONE_CONFIG_URL" "$RCLONE_CONFIG"
          export RCLONE_HTPASSWD_URL="''${RCLONE_HTPASSWD_URL:-$RCLONE_CONFIG_URL}"

          ${downloadCommand}
          RCLONE_RCD_HTPASSWD="${htpasswdFile}"

          # Additional random user to control the rcd instance
          export RCLONE_RC_USER=userforlocalrcdaccess
          RCLONE_RC_PASS=
          RCLONE_RC_PASS="$(openssl rand -base64 20)"
          export RCLONE_RC_PASS
          echo >> "$RCLONE_RCD_HTPASSWD"
          echo "$RCLONE_RC_USER:$(openssl passwd -apr1 "$RCLONE_RC_PASS")" >> "$RCLONE_RCD_HTPASSWD"

          rclone rcd --cache-dir ${home}/cache --rc-addr :${builtins.toString rclonePort} --rc-baseurl ${rcloneUrl} --rc-web-gui --rc-web-gui-no-open-browser --rc-htpasswd "$RCLONE_RCD_HTPASSWD" &
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
        bash
        caCertificates
        fakeNss
        coreutils
        openssl

        tini

        openresty
        curl
        rclone

        entrypoint
      ];

      extraCommands =
        let
          version = "2.0.5";
          source = fetchTarball {
            url = "https://github.com/rclone/rclone-webui-react/releases/download/v${version}/currentbuild.zip";
            sha256 = "sha256:05qggiqg9lskna5zsjrayzx8ngkfx80cn2qdly6y5vza4vrx62nz";
          };
        in
        ''
          mkdir -p -m 1777 ./tmp
          mkdir -p -m 1755 ./data/cache/webgui/current/build/
          # Docker volume mount may shadow this directory,
          # but this is our best take because rclone does not accept
          # a parameter to specify the web gui path.
          cp -r ${source}/. ./data/cache/webgui/current/build
          printf '%s' 'v${version}' > ./data/cache/webgui/tag
        '';

      config = {
        ExposedPorts = {
          "${builtins.toString exposedPort}/tcp" = { };
        };
        WorkingDir = "${home}";
        Volumes = {
          "${home}" = { };
        };
        Entrypoint = [
          "${lib.getExe tini}"
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

  aria2 =
    with pkgs;
    let
      home = "/data";
      uid = 1000;
      gid = 100;
      ugid = "${builtins.toString uid}:${builtins.toString gid}";
      exposedPort = 10000;
      basicAuthRealm = "aria2";
      webdavPort = 5573;
      aria2Port = 6801;
      mntPath = "/mnt/aria2";
      ui =
        let
          version = "1.3.13";
        in
        fetchTarball {
          url = "https://github.com/mayswind/AriaNg/releases/download/${version}/AriaNg-${version}.zip";
          sha256 = "sha256:1bhq503jxnz19v1spwp9lqc0dw8gzy3hcddqrxasfw5zn93fq5ga";
        };
      configFile = "/tmp/rclone.conf";
      htpasswdFile = "/tmp/rclone.htpasswd";
      nginxConfig = writers.writeNginxConfig "nginx.conf" ''
        events {}

        http {
          sendfile on;
          client_max_body_size 0;
          tcp_nopush on;
          tcp_nodelay on;
          keepalive_timeout 65;
          access_log /dev/stdout;
          upstream webdav {
            server 127.0.0.1:${builtins.toString webdavPort};
          }
          upstream aria2 {
            server 127.0.0.1:${builtins.toString aria2Port};
          }

          server {
            listen *:${builtins.toString exposedPort};
            server_name _;

            location /webdav {
              proxy_pass http://webdav;
            }
            location /ui/ {
              alias ${ui}/;
              autoindex off;
              include ${nginx}/conf/mime.types;
            }
            location /jsonrpc {
              proxy_pass http://aria2;
            }
            location /rpc {
              proxy_pass http://aria2;
            }
          }
        }
      '';
      aria2Config = writeText "aria2.conf" ''
        enable-rpc=true
        rpc-allow-origin-all=true
        rpc-listen-all=true
        max-concurrent-downloads=5
        continue=true
        max-connection-per-server=5
        min-split-size=10M
        split=10
        max-overall-download-limit=0
        max-download-limit=0
        max-overall-upload-limit=0
        max-upload-limit=0
        disk-cache=0
        enable-mmap=false
        file-allocation=none
        save-session-interval=60
      '';
      entrypointName = "container-entrypoint";
      entrypoint = writeShellApplication {
        name = entrypointName;
        text = ''
          set -x
          rclone copyurl "$RCLONE_CONFIG_URL" "${configFile}"
          rclone copyurl "$RCLONE_CONFIG_URL&htpasswd=downloads" "${htpasswdFile}"
          rclone --config "${configFile}" mount --vfs-cache-mode=full "$RCLONE_REMOTE" "${mntPath}" &
          rclone --config "${configFile}" serve webdav --addr=":${builtins.toString webdavPort}" --baseurl=webdav --realm="${basicAuthRealm}" --htpasswd="${htpasswdFile}" "${mntPath}" &
          aria2c --conf-path="${aria2Config}" --rpc-listen-port="${builtins.toString aria2Port}" --dir="${mntPath}" --rpc-secret="$ARIA2_RPC_SECRET" --daemon=false &
          nginx -e stderr -p . -c "${nginxConfig}" -g 'daemon off; pid /tmp/nginx.pid; error_log stderr info;' &
          wait -n
        '';
      };
    in
    dockerTools.buildLayeredImage {
      name = "aria2";
      tag = "latest";
      maxLayers = 10;
      contents = with pkgs.dockerTools; [
        usrBinEnv
        binSh
        caCertificates
        coreutils
        openssl

        tini

        openresty
        curl
        rclone
        aria2

        entrypoint
      ];

      enableFakechroot = true;
      fakeRootCommands =
        let
          paths = [
            mntPath
          ]
          ++ [
            # Paths obtained from
            # strings ./result/bin/nginx | grep '/tmp'
            "/tmp/nginx_client_body"
            "/tmp/nginx_proxy"
            "/tmp/nginx_fastcgi"
            "/tmp/nginx_uwsgi"
            "/tmp/nginx_scgi"
          ];
          mkPath = path: ''
            mkdir -p "${path}"
            chown -R "${ugid}" "${path}"
            chmod -R 755 "${path}"
          '';
          fixPathsCmd = lib.concatMapStringsSep "\n" mkPath paths;
        in
        ''
          ${dockerTools.shadowSetup}
          groupadd -r -g "${builtins.toString gid}" users
          useradd -r -g "${builtins.toString gid}" -u "${builtins.toString uid}" --home-dir ${home} --create-home user
          ${fixPathsCmd}
        '';

      extraCommands = ''
        mkdir -p -m 1777 ./tmp
        mkdir -p -m 1777 ./mnt
      '';

      config = {
        User = ugid;
        ExposedPorts = {
          "${builtins.toString exposedPort}/tcp" = { };
        };
        WorkingDir = "${home}";
        Volumes = {
          "${home}" = { };
        };
        Entrypoint = [
          "${lib.getExe tini}"
          "--"
        ];
        Cmd = [
          "/bin/${entrypointName}"
        ];
        Env = [
          "HOME=${home}"
          # $PATH seems to be unset in fly.io
          "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
        ];
      };
    };

  tailscale =
    with pkgs;
    dockerTools.buildLayeredImage {
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
      caddyConfigPath = "/etc/caddy/config.json";
      caddyConfig = pkgs.writeTextDir caddyConfigPath (
        builtins.toJSON {
          admin = {
            listen = "{env.ADMIN_LISTEN_ADDR}";
            config = {
              load = {
                module = "http";
                url = "{env.CADDY_CONFIG_URL}";
              };
            };
          };
        }
      );
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
        tini

        caddy
        caddyConfig
      ];

      config = {
        Volumes = {
          "/data" = { };
        };
        WorkingDir = "/data";
        Entrypoint = [
          "${lib.getExe tini}"
          "--"
        ];
        Cmd = [
          "${lib.getExe caddy}"
          "run"
          "--config"
          "${caddyConfigPath}"
        ];
        Env = [
          # XDG_CONFIG_HOME and XDG_DATA_HOME are used by some of the
          # caddy modules, e.g. caddy-tailscale
          "XDG_CONFIG_HOME=/data/.config"
          "XDG_DATA_HOME=/data/.local/share"
          "ADMIN_LISTEN_ADDR=:2019"
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
      frontend =
        let
          source = fetchTarball {
            url = "https://github.com/owntracks/frontend/releases/download/v2.15.3/v2.15.3-dist.zip";
            sha256 = "sha256:1a9qphygid1rajgn5mifp5y2wz13bsym329wjpv3yf6w4chv4bwb";
          };
        in
        pkgs.runCommand "frontend" { } ''
          set -x
          mkdir -p $out/config/
          cp ${source}/config/config.example.js $out/config/config.js
          cp -r ${source}/. $out
        '';
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
                    gzip on;
                    gzip_vary on;
                    gzip_proxied any;
                    gzip_comp_level 6;
                    gzip_buffers 16 8k;
                    gzip_http_version 1.1;
                    gzip_types text/plain text/css application/json application/javascript text/javascript;
                    proxy_read_timeout 600;

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

                    location = /frontend {
                        return 301 $scheme://$http_host/frontend/;
                    }
                    location /frontend/ {
                        auth_basic "Administrator’s Area";
                        auth_basic_user_file ${adminHtpasswdPath};
                        alias ${frontend}/;
                        autoindex off;
                        include ${nginx}/conf/mime.types;
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
