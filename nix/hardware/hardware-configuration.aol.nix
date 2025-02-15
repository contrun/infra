{ config, lib, pkgs, modulesPath, ... }:

{
  imports = [ (modulesPath + "/installer/scan/not-detected.nix") ];

  boot.initrd.availableKernelModules = [
    "xhci_pci"
    "thunderbolt"
    "vmd"
    "nvme"
    "usbhid"
    "usb_storage"
    "sd_mod"
    "sdhci_pci"
  ];
  boot.initrd.kernelModules = [ ];
  boot.kernelModules = [ "kvm-intel" ];
  boot.extraModulePackages = [ ];

  fileSystems."/" = {
    device = "rpool/ROOT/nixos";
    fsType = "zfs";
  };

  fileSystems."/nix" = {
    device = "rpool/NIX/nix";
    fsType = "zfs";
  };

  fileSystems."/var" = {
    device = "rpool/VAR/var";
    fsType = "zfs";
  };

  fileSystems."/home" = {
    device = "rpool/HOME/home";
    fsType = "zfs";
  };

  fileSystems."/tmp" = {
    device = "rpool/TMP/tmp";
    fsType = "zfs";
  };

  fileSystems."/boot" = {
    device = "/dev/disk/by-uuid/AB92-AD35";
    fsType = "vfat";
  };

  fileSystems."/boot1" = {
    device = "/dev/disk/by-uuid/AB93-7964";
    fsType = "vfat";
  };

  swapDevices = [ ];

  # Enables DHCP on each ethernet and wireless interface. In case of scripted networking
  # (the default) this is the recommended approach. When using systemd-networkd it's
  # still possible to use this option, but it's recommended to use it in conjunction
  # with explicit per-interface declarations with `networking.interfaces.<interface>.useDHCP`.
  networking.useDHCP = lib.mkDefault true;
  # networking.interfaces.eno2.useDHCP = lib.mkDefault true;
  # networking.interfaces.wlo1.useDHCP = lib.mkDefault true;

  services.xserver.videoDrivers = [ "nvidia" ];

  powerManagement.cpuFreqGovernor = lib.mkDefault "powersave";

  hardware = {
    cpu.intel.updateMicrocode =
      lib.mkDefault config.hardware.enableRedistributableFirmware;

    nvidia = {
      open = true;
      modesetting.enable = true;
      powerManagement.enable = true;
      powerManagement.finegrained = true;
      package = config.boot.kernelPackages.nvidiaPackages.beta;
      prime = {
        offload = {
          enable = true;
          enableOffloadCmd = true;
        };
        nvidiaBusId = "PCI:1:0:0";
        intelBusId = "PCI:0:2:0";
      };
    };
  };
}
