{
  config,
  options,
  lib,
  ...
}:

let
  cfg = config.prefs.ap;
in
{
  options.prefs.ap = {
    inherit (options.services.create_ap) enable settings;
    autostart = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to autostart the ap daemon";
    };
  };

  config = {
    services.create_ap = {
      inherit (cfg) enable settings;
    };
    systemd.services.create_ap = {
      wantedBy = lib.mkIf (!cfg.autostart) (lib.mkForce [ ]);
    };
  };
}
