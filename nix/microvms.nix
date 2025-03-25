{
  self,
  microvm,
  nixpkgs,
  system,
}:
let
  pkgs = import nixpkgs {
    inherit system;
  };
  lib = pkgs.lib;
in
{
  graphics = {
    inherit pkgs;

    config = {
      system = {
        stateVersion = lib.trivial.release;
      };

      microvm = {
        hypervisor = "cloud-hypervisor";
        graphics.enable = true;
        balloonMem = 1536;
        vcpu = 8;
      };

      networking.hostName = "graphical-microvm";
      nixpkgs = {
        overlays = [
          microvm.overlay
        ];
      };

      services.getty.autologinUser = "user";
      users.users.user = {
        password = "";
        group = "user";
        isNormalUser = true;
        extraGroups = [
          "wheel"
          "video"
        ];
      };
      users.groups.user = { };
      security.sudo = {
        enable = true;
        wheelNeedsPassword = false;
      };

      environment.sessionVariables = {
        WAYLAND_DISPLAY = "wayland-1";
        DISPLAY = ":0";
        QT_QPA_PLATFORM = "wayland"; # Qt Applications
        GDK_BACKEND = "wayland"; # GTK Applications
        XDG_SESSION_TYPE = "wayland"; # Electron Applications
        SDL_VIDEODRIVER = "wayland";
        CLUTTER_BACKEND = "wayland";
      };

      systemd.user.services.wayland-proxy = {
        enable = true;
        description = "Wayland Proxy";
        serviceConfig = with pkgs; {
          # Environment = "WAYLAND_DISPLAY=wayland-1";
          ExecStart = "${wayland-proxy-virtwl}/bin/wayland-proxy-virtwl --virtio-gpu --x-display=0 --xwayland-binary=${xwayland}/bin/Xwayland";
          Restart = "on-failure";
          RestartSec = 5;
        };
        wantedBy = [ "default.target" ];
      };

      environment.systemPackages = with pkgs; [
        xdg-utils # Required
        firefox-wayland
        librewolf-wayland
      ];

      hardware.graphics.enable = true;
    };
  };
}
