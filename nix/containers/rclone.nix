{ pkgs, lib, ... }:
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
}
