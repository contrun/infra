{
  lib,
  config,
  ...
}:
let
  cfg = config.prefs.nvidia;
  nvidiaEnabled = config.hardware.nvidia.enabled && !cfg.disable;
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
      description = "Whether enable cuda support for nixpkgs, default to `hardware.nvidia.enabled && !prefs.nvidia.disable`";
    };
  };

  config = {
    hardware.nvidia = {
      inherit (cfg) open;
    };
    nixpkgs.config.cudaSupport = cfg.enableNixpkgsCudaSupport;
    nix = lib.mkIf nvidiaEnabled {
      settings = {
        substituters = [ "https://cache.nixos-cuda.org" ];
        trusted-public-keys = [ "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=" ];
      };
    };
  };
}
