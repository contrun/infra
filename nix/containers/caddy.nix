{
  pkgs,
  lib,
  packages,
  ...
}:
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
}
