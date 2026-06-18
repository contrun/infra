{
  lib,
  config,
  options,
  ...
}:
let
  cfg = config.prefs.ssh;
in
{
  options.prefs.ssh = {
    enableTpmAgent = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to tpm-ssh-agent";
    };
    startAgent = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = "Whether to start ssh agent";
    };
    extraConfig = options.programs.ssh.extraConfig // {
      default = ''
        Include ssh_config.d/*
      '';
    };
  };

  config = {
    services.ssh-tpm-agent.enable = cfg.enableTpmAgent;
    programs.ssh.startAgent = cfg.startAgent;
    programs.ssh.extraConfig = cfg.extraConfig;
  };
}
