{
  lib,
  config,
  ...
}:
let
  cfg = config.prefs.nvidia;
  nvidiaEnabled = config.hardware.nvidia.enabled;
in
{
  options.prefs.nvidia = {
    open = lib.mkOption {
      type = lib.types.bool;
      default = true;
      description = "Whether to use open source kernel module";
    };
    enableNixpkgsCudaSupport = lib.mkOption {
      type = lib.types.bool;
      default = nvidiaEnabled;
      description = "Whether enable cuda support for nixpkgs, default to `hardware.nvidia.enabled`";
    };
  };

  config = {
    hardware.nvidia = {
      inherit (cfg) open;
    };
  nixpkgs.config.cudaSupport = cfg.enableNixpkgsCudaSupport;
  };
}
