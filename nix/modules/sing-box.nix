{
  config,
  lib,
  ...
}:

let
  cfg = config.prefs.sing-box;
in
{
  options.prefs.sing-box = {
    enable = lib.mkEnableOption "Whether to enable sing-box";

    configPath = lib.mkOption {
      type = lib.types.path;
      default = "/etc/sing-box/config.json";
      description = "The path to the sing-box config file";
    };
  };

  config = lib.mkIf cfg.enable {
    services.sing-box = {
      enable = true;
    };
    systemd.services = {
      sing-box = {
        serviceConfig = {
          ExecStartPre = lib.mkForce [
            ""
          ];
          ExecStart = lib.mkForce [
            ""
            ''
              ${lib.getExe config.services.sing-box.package} -D ''${STATE_DIRECTORY} -c "${cfg.configPath}" run
            ''
          ];
        };
      };
    };
  };
}
