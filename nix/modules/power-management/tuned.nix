{
  config,
  lib,
  options,
  pkgs,
  ...
}:

let
  cfg = config.prefs.tuned;
  profileFormat = pkgs.formats.ini { };
in
{
  options.prefs.tuned = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = config.prefs.machine.hasBattery;
      inherit (options.services.tuned.enable) description;
    };
    extraExtremePowersaveRules = lib.mkOption {
      type = lib.types.submodule {
        freeformType = profileFormat.type;
      };
      default = { };
      description = "Extra rules for the extreme-powersave profile";
    };
  };

  config = lib.mkIf cfg.enable (
    let
      extreme-powersave = "extreme-powersave";
    in
    {
      services.tuned.enable = true;
      services.tuned.settings = {
        daemon = lib.mkDefault true;
      };

      environment.etc = {
        "tuned/profiles/${extreme-powersave}/script.sh" = {
          source =
            let
              getShellArgs =
                with lib;
                let
                  hasExtension = name: builtins.match ".*\\.[a-z]+" name != null;
                  addExtension = name: if (hasExtension name) then name else "${name}.service";
                  f = unit: escapeShellArg (addExtension unit);
                in
                list: concatMapStringsSep " " f list;
              systemUnits = getShellArgs [
                "pipewire*"
                "vboxnet0"
                "tailscaled"
                "wstunnel"
                "wg-quick-*"
                "eternal-terminal"
                "promtail"
                "prometheus"
                "prometheus-*.service"
                "cadvisor"
                "docker"
                "docker.socket"
                "docker-*.service"
                "zerotierone"
                "zerotierone-*"
                "glusterd"
                "glustereventsd"
                "syncthing"
                "aria2"
                "chronyd"
                "cups-browsed"
                "nfs-idmapd"
                "nfs-mountd"
                "nfsdcld"
                "pcscd*"
                "rpc-statd"
                "rpcbind*"
                "system-samba.slice"
                "vsftpd"
                "waydroid-container"
                "avahi-daemon*"
                "postfix"
                "ydotoold"
                "caddy"
                "system-cups.slice"
              ];
              userUnits = getShellArgs [
                "pipewire*"
                "syncthing"
                "tomat"
                "emacs"
                "auto-fix-vscode-server"
                "app-unison.slice"
                "offlineimap*"
              ];
            in
            pkgs.writeShellScript extreme-powersave ''
              set -x

              start() {
                  systemctl stop ${systemUnits}
                  systemctl --user --machine=e@ stop ${userUnits}
                  return 0
              }

              stop() {
                  systemctl list-unit-files --state=enabled --output json ${systemUnits} | \
                      ${lib.getExe pkgs.jq} -r '.[].unit_file' | \
                      xargs --no-run-if-empty --verbose systemctl start

                  systemctl list-unit-files --user --machine=e@ --state=enabled --output json ${userUnits} | \
                      ${lib.getExe pkgs.jq} -r '.[].unit_file' | \
                      xargs --no-run-if-empty --verbose systemctl start --user --machine=e@

                  return 0
              }

              process() {
                  ARG="$1"
                  shift
                  case "$ARG" in
                      start)
                          start "$@"
                          RETVAL=$?
                          ;;
                      stop)
                          stop "$@"
                          RETVAL=$?
                          ;;
                      verify)
                          if declare -f verify &> /dev/null; then
                              verify "$@"
                          else
                              :
                          fi
                          RETVAL=$?
                          ;;
                      *)
                          echo "Usage: $0 {start|stop|verify}"
                          RETVAL=2
                          ;;
                  esac
                  exit $RETVAL
              }

              process "$@"
            '';
          mode = "0555";
        };
      };
      services.tuned.profiles.${extreme-powersave} = {
        main = {
          include = "powersave";
        };
        services = {
          type = "script";
          # We must put the script inside the profile path, otherwise we have
          # Paths outside of the profile directories cannot be used in the script, ignoring script: xxx
          script = "\${i:PROFILE_DIR}/script.sh";
        };
      }
      // cfg.extraExtremePowersaveRules;
    }
  );
}
