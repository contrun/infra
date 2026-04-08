{
  config,
  lib,
  options,
  ...
}:

let
  cfg = config.prefs.upower;
in
{
  options.prefs.upower = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.prefs.machine.hasBattery;
      inherit (options.services.upower.enable) description;
    };
  };

  config = lib.mkIf cfg.enable {
    services.upower = {
      enable = true;
      criticalPowerAction = lib.mkDefault "PowerOff";
    };
  };
}
