{
  pkgs,
  lib,
  ...
}:
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
}
