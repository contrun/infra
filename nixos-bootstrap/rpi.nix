{ pkgs, ... }:

{
  # Tell the host system that it can, and should, build for aarch64.
  nixpkgs = rec {
    crossSystem = (import <nixpkgs> { }).pkgsCross.aarch64-multiplatform.stdenv.targetPlatform;
    localSystem = crossSystem;
  };

  fileSystems."/" = {
    device = "default/ROOT/nixos";
    fsType = "zfs";
  };

  fileSystems."/nix" = {
    device = "default/NIX/nix";
    fsType = "zfs";
  };

  fileSystems."/tmp" = {
    device = "default/TMP/tmp";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "default/HOME/home";
    fsType = "zfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/72F2-21CB";
    fsType = "vfat";
  };

  services.xserver = {
    enable = true;
    displayManager.lightdm.enable = true;
    desktopManager.xterm.enable = false;
    windowManager.i3.enable = true;
    videoDrivers = [ "fbdev" ];
  };

  hardware.enableRedistributableFirmware = true;

  networking.hostName = "shl";
  networking.hostId = "6fce2459";
  users.users.exampleuser = {
    isNormalUser = true;
    password = "badpassword";
  };

  users.users.root = {
    password = "badpassword";
  };
  # For the ugly hack to run the activation script in the chroot'd host below. Remove after sd card is set up.
  environment.etc."binfmt.d/nixos.conf".text =
    ":aarch64:M::\\x7fELF\\x02\\x01\\x01\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x00\\x02\\x00\\xb7\\x00:\\xff\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xff\\xff\\xff\\xff\\xff\\x00\\xff\\xfe\\xff\\xff\\xff:/run/binfmt/aarch64:";
  boot = {
    kernelPackages = pkgs.linuxPackages_rpi4;
    loader = {
      grub.enable = false;
      raspberryPi = {
        enable = true;
        version = 4;
      };
    };
  };
}
