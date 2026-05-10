{ pkgs, lib, ... }:
with pkgs;
let
  home = "/data";
  uid = 1000;
  gid = 100;
  ugid = "${builtins.toString uid}:${builtins.toString gid}";
  exposedPort = 10000;
  webdavPort = 4999;
  basicAuthRealm = "hledger";
  lang = "en_US.UTF-8";
  locale_archive = "${glibcLocales}/lib/locale/locale-archive";
  mntPath = "/mnt/hledger";
  socketPath = "/tmp/hledger";
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

      server {
        listen *:${builtins.toString exposedPort};
        server_name _;

        location /webdav {
          proxy_pass http://webdav;
        }

        location ~ ^/(?<name>[^/]+)(?<path>.*) {
          auth_basic "${basicAuthRealm}";
          auth_basic_user_file "${htpasswdFile}";

          proxy_pass http://unix:${socketPath}/$remote_user:$path;

          proxy_set_header Host $host;
          proxy_set_header X-Real-IP $remote_addr;
          proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
          proxy_set_header X-Forwarded-User $remote_user;
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
      rclone --config "${configFile}" mount --vfs-cache-mode=full --log-file /tmp/rclone.log --log-format pid --daemon "$RCLONE_REMOTE" "${mntPath}"
      rclone --config "${configFile}" serve webdav --addr=":${builtins.toString webdavPort}" --baseurl=webdav --realm="${basicAuthRealm}" --htpasswd="${htpasswdFile}" "${mntPath}" &
      mkdir -p "${socketPath}"
      cut -d: -f1 /tmp/rclone.htpasswd | while read -r i; do
        if [[ $i ]] && [[ -f "${mntPath}/$i.hledger" ]]; then
          ${lib.getExe hledger-web} --serve --file "${mntPath}/$i.hledger" --socket "${socketPath}/$i" --base-url "$BASE_URL/$i" &
        fi
      done
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
      "BASE_URL=http://127.0.0.1:${builtins.toString exposedPort}"
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
