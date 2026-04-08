{
  lib,
  config,
  ...
}:
{
  options.prefs.machine = {
    type = lib.mkOption {
      type = lib.types.enum [
        "desktop"
        "laptop"
        "server"
      ];
      default = "desktop";
      description = "The type of hardware this configuration is targeting.";
    };

    isLaptop = lib.mkOption {
      type = lib.types.bool;
      default = config.prefs.machine.type == "laptop";
      description = "Whether the host is a laptop. Defaults to true if type is 'laptop'.";
    };

    hasBattery = lib.mkOption {
      type = lib.types.bool;
      default = config.prefs.machine.type == "laptop";
      description = "Whether the host has battery.";
    };
  };
}
