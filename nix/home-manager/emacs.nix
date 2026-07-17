{
  lib,
  config,
  ...
}:
let
  cfg = config.prefs.emacs;
in
{
  options.prefs.emacs = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to enable Emacs user service";
    };
    client = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = cfg.enable;
        description = "Whether to enable Emacs client";
      };
    };
    socketActivation = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Whether to enable systemd socket activation for Emacs";
      };
    };
  };

  config = {
    services.emacs = {
      enable = cfg.enable;
      client = {
        enable = cfg.client.enable;
      };
      socketActivation = {
        enable = cfg.socketActivation.enable;
      };
    };
  };
}
