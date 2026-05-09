{ pkgs, lib, ... }:
with pkgs;
let
  home = "/data";
  uid = 1000;
  gid = 100;
  ugid = "${builtins.toString uid}:${builtins.toString gid}";
  exposedPort = 5000;
  webdavPort = 4999;
  baseHledgerPort = 5001;
  basicAuthRealm = "hledger";
  lang = "en_US.UTF-8";
  locale_archive = "${glibcLocales}/lib/locale/locale-archive";
  mntPath = "/mnt/hledger";
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

      # Shared memory to track which ledger is on which port
      lua_shared_dict ledger_ports 64k;
      # To ensure port assignment is atomic
      lua_shared_dict port_counter 12k;

      upstream webdav {
        server 127.0.0.1:${builtins.toString webdavPort};
      }

      init_by_lua_block {
          local port_counter = ngx.shared.port_counter
          port_counter:set("next_port", ${builtins.toString baseHledgerPort})
      }

      server {
        listen *:${builtins.toString exposedPort};
        server_name _;

        location /webdav {
          proxy_pass http://webdav;
        }

        location ~ ^/(?<ledger_name>[^/]+) {
          set $maybe_skip_auth "${basicAuthRealm}";
          if ($uri ~* "/static/") {
            set $auth_state "off";
          }
          auth_basic $maybe_skip_auth;
          auth_basic_user_file "${htpasswdFile}";

          access_by_lua_block {
              local ngx = require "ngx"
              local ledger_name = ngx.var.ledger_name
              local remote_user = ngx.var.remote_user

              -- Verify user 'default' is accessing path '/default'
              if remote_user ~= ledger_name then
                  ngx.log(ngx.ERR, "User " .. remote_user .. " denied access to " .. ledger_name)
                  return ngx.exit(ngx.HTTP_FORBIDDEN)
              end

              local ports = ngx.shared.ledger_ports
              local port = ports:get(ledger_name)

              if not port then
                  local counter = ngx.shared.port_counter
                  local next_port = counter:incr("next_port", 1) - 1
                  local log_file = "/tmp/hledger-" .. ledger_name .. ".log"
                  local ngx_pipe = require "ngx.pipe"
                  local cmd = {
                      "${lib.getExe hledger-web}",
                      "--serve",
                      "--file", "${mntPath}/" .. ledger_name .. ".hledger",
                      "--port", tostring(next_port),
                      "--base-url", ngx.var.scheme .. "://" .. ngx.var.host .. ":" .. tostring(ngx.var.server_port) .. "/" .. ledger_name,
                  }
                  local opts = {
                      environ = {
                        "LANG=${lang}",
                        "LC_ALL=${lang}",
                        "LOCALE_ARCHIVE=${locale_archive}",
                      },
                  }
                  ngx.log(ngx.INFO, "Spawning hledger-web for " .. ledger_name .. " on port " .. next_port .. ". Logs: " .. log_file .. " Command: " .. table.concat(cmd, " "))
                  local proc, err = ngx_pipe.spawn(cmd, opts)
                  if not proc then
                      ngx.log(ngx.ERR, "Failed to spawn hledger: ", err)
                      return ngx.exit(500)
                  end

                  ngx.thread.spawn(function()
                      while true do
                          local data, err = proc:stdout_read_any(8096)
                          if not data then break end
                          ngx.log(ngx.INFO, "hledger-web stdout: ", data)
                      end
                  end)

                  ngx.thread.spawn(function()
                      while true do
                          local data, err = proc:stderr_read_any(8096)
                          if not data then break end
                          ngx.log(ngx.ERR, "hledger-web stderr: ", data)
                      end
                  end)

                  ports:set(ledger_name, next_port)
                  port = next_port
              end
              ngx.var.target_port = port
          }

          set $target_port "";
          proxy_pass http://127.0.0.1:$target_port;
          # Standard proxy headers
          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        }
      }
    }
  '';
  entrypointName = "container-entrypoint";
  entrypoint = writeShellApplication {
    name = entrypointName;
    text = ''
      set -x
      rclone copyurl "$RCLONE_CONFIG_URL" "${configFile}"
      rclone copyurl "$RCLONE_CONFIG_URL&htpasswd=hledger" "${htpasswdFile}"
      rclone --config "${configFile}" mount --vfs-cache-mode=full "$RCLONE_REMOTE" "${mntPath}" &
      rclone --config "${configFile}" serve webdav --addr=":${builtins.toString webdavPort}" --baseurl=webdav --realm="${basicAuthRealm}" --htpasswd="${htpasswdFile}" "${mntPath}" &
      nginx -e stderr -p . -c "${nginxConfig}" -g 'daemon off; pid /tmp/nginx.pid; error_log stderr info;' &
      wait -n
    '';
  };
in
dockerTools.buildLayeredImage {
  name = "hledger";
  tag = "latest";
  contents = with pkgs.dockerTools; [
    usrBinEnv
    binSh
    caCertificates
    glibcLocales
    coreutils
    openssl

    tini

    openresty
    curl
    rclone
    hledger
    hledger-ui
    hledger-web

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
      # Fix local errors for hledger
      "LANG=${lang}"
      "LC_ALL=${lang}"
      "LOCALE_ARCHIVE=${locale_archive}"
    ];
  };
}
