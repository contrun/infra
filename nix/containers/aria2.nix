{ pkgs, lib, ... }:
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
  ui = "${ariang}/share/ariang";
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
}
