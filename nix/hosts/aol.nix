{
  ...
}:
{
  hardware.wireless.regulatoryDomain = "CN";
  prefs.machine.type = "laptop";
  prefs.nvidia = {
    open = false;
    # I think the hardware is broken.
    # I have the following log from the open source driver
    # Aug 23 00:54:55 aol kernel: nvidia-nvlink: Nvlink Core is being initialized, major device number 242
    # Aug 23 00:54:55 aol kernel: NVRM: loading NVIDIA UNIX Open Kernel Module for x86_64  595.71.05  Release Build  (nixbld@)
    # Aug 23 00:54:55 aol kernel: nvidia-modeset: Loading NVIDIA UNIX Open Kernel Mode Setting Driver for x86_64  595.71.05  Release Build  (nixbld@)
    # Aug 23 00:54:55 aol kernel: [drm] [nvidia-drm] [GPU ID 0x00000100] Loading driver
    # Aug 23 00:54:56 aol kernel: NVRM: GPU0 kgspExecuteFwsec_TU102: failed to execute FWSEC for FRTS: FRTS error code 0x492f
    # Aug 23 00:54:56 aol kernel: NVRM: GPU0 kgspExecuteFwsec_TU102: (note: VBIOS version 94.06.2B.00.55)
    # Aug 23 00:54:56 aol kernel: NVRM: GPU0 nvAssertOkFailedNoLog: Assertion failed: Failure: Generic Error [NV_ERR_GENERIC] (0x0000FFFF) returned from status @ kernel_gsp_tu102.c:511
    # Aug 23 00:54:56 aol kernel: NVRM: GPU0 _kgspBootGspRm: unexpected WPR2 already up, cannot proceed with booting GSP
    # Aug 23 00:54:56 aol kernel: NVRM: GPU0 _kgspBootGspRm: (the GPU is likely in a bad state and may need to be reset)
    # Aug 23 00:54:56 aol kernel: NVRM: GPU0 RmInitAdapter: Cannot initialize GSP firmware RM
    # Aug 23 00:54:56 aol kernel: NVRM: GPU 0000:01:00.0: RmInitAdapter failed! (0x62:0x40:2168)
    # Aug 23 00:54:56 aol kernel: NVRM: GPU 0000:01:00.0: rm_init_adapter failed, device minor number 0
    # Aug 23 00:54:56 aol kernel: [drm:nv_drm_dev_load [nvidia_drm]] *ERROR* [nvidia-drm] [GPU ID 0x00000100] Failed to allocate NvKmsKapiDevice
    # Aug 23 00:55:12 aol kernel: NVRM: GPU0 nvAssertFailed: Assertion failed: 0 @ g_kernel_sec2_nvoc.h:857
    # Aug 23 00:55:12 aol kernel: NVRM: GPU0 nvAssertFailedNoLog: Assertion failed: pBinArchive != NULL @ kernel_gsp_booter.c:487
    # Aug 23 00:55:12 aol kernel: NVRM: GPU0 nvCheckOkFailedNoLog: Check failed: Call not supported [NV_ERR_NOT_SUPPORTED] (0x00000056) returned from kgspAllocateScrubberUcodeImage(pGpu, pKernelGsp, &pKernelGsp->pScrubberUcode) @ kernel_gsp.c:4370
    # Aug 23 00:55:12 aol kernel: NVRM: GPU0 nvCheckOkFailedNoLog: Check failed: Call not supported [NV_ERR_NOT_SUPPORTED] (0x00000056) returned from _kgspPrepareScrubberImageIfNeeded(pGpu, pKernelGsp) @ kernel_gsp.c:4730
    # Aug 23 00:55:12 aol kernel: NVRM: GPU0 RmInitAdapter: Cannot initialize GSP firmware RM
    # Aug 23 00:55:12 aol kernel: NVRM: GPU 0000:01:00.0: RmInitAdapter failed! (0x62:0x56:2168)
    # Aug 23 00:55:12 aol kernel: NVRM: GPU 0000:01:00.0: rm_init_adapter failed, device minor number 0
    # Aug 23 00:55:12 aol kernel: NVRM: GPU0 nvAssertFailed: Assertion failed: 0 @ g_kernel_sec2_nvoc.h:857
    # Aug 23 00:55:12 aol kernel: NVRM: GPU0 nvAssertFailedNoLog: Assertion failed: pBinArchive != NULL @ kernel_gsp_booter.c:487
    # Aug 23 00:55:12 aol kernel: NVRM: GPU0 nvCheckOkFailedNoLog: Check failed: Call not supported [NV_ERR_NOT_SUPPORTED] (0x00000056) returned from kgspAllocateScrubberUcodeImage(pGpu, pKernelGsp, &pKernelGsp->pScrubberUcode) @ kernel_gsp.c:4370
    # Aug 23 00:55:12 aol kernel: NVRM: GPU0 nvCheckOkFailedNoLog: Check failed: Call not supported [NV_ERR_NOT_SUPPORTED] (0x00000056) returned from _kgspPrepareScrubberImageIfNeeded(pGpu, pKernelGsp) @ kernel_gsp.c:4730
    # Aug 23 00:55:12 aol kernel: NVRM: GPU0 RmInitAdapter: Cannot initialize GSP firmware RM
    # Aug 23 00:55:12 aol kernel: NVRM: GPU 0000:01:00.0: RmInitAdapter failed! (0x62:0x56:2168)
    # Aug 23 00:55:12 aol kernel: NVRM: GPU 0000:01:00.0: rm_init_adapter failed, device minor number 0
    # Aug 23 00:55:12 aol kernel: NVRM: GPU0 nvAssertFailed: Assertion failed: 0 @ g_kernel_sec2_nvoc.h:857
    # Aug 23 00:55:12 aol kernel: NVRM: GPU0 nvAssertFailedNoLog: Assertion failed: pBinArchive != NULL @ kernel_gsp_booter.c:487
    # Aug 23 00:55:12 aol kernel: NVRM: GPU0 nvCheckOkFailedNoLog: Check failed: Call not supported [NV_ERR_NOT_SUPPORTED] (0x00000056) returned from kgspAllocateScrubberUcodeImage(pGpu, pKernelGsp, &pKernelGsp->pScrubberUcode) @ kernel_gsp.c:4370
    # Aug 23 00:55:12 aol kernel: NVRM: GPU0 nvCheckOkFailedNoLog: Check failed: Call not supported [NV_ERR_NOT_SUPPORTED] (0x00000056) returned from _kgspPrepareScrubberImageIfNeeded(pGpu, pKernelGsp) @ kernel_gsp.c:4730
    # Aug 23 00:55:12 aol kernel: NVRM: GPU0 RmInitAdapter: Cannot initialize GSP firmware RM
    # Aug 23 00:55:12 aol kernel: NVRM: GPU 0000:01:00.0: RmInitAdapter failed! (0x62:0x56:2168)
    # Aug 23 00:55:12 aol kernel: NVRM: GPU 0000:01:00.0: rm_init_adapter failed, device minor number 0

    # I have the following log from the proprietary driver
    # Aug 28 12:21:09 aol kernel: nvidia-nvlink: Nvlink Core is being initialized, major device number 240
    # Aug 28 12:21:09 aol kernel: NVRM: loading NVIDIA UNIX x86_64 Kernel Module  595.71.05  Fri Apr 24 06:36:12 UTC 2026
    # Aug 28 12:21:10 aol kernel: nvidia-modeset: Loading NVIDIA Kernel Mode Setting Driver for UNIX platforms  595.71.05  Fri Apr 24 06:27:06 UTC 2026
    # Aug 28 12:21:10 aol kernel: [drm] [nvidia-drm] [GPU ID 0x00000100] Loading driver
    # Aug 28 12:21:11 aol kernel: NVRM: GPU 0000:01:00.0: RmInitAdapter failed! (0x62:0x40:2830)
    # Aug 28 12:21:11 aol kernel: NVRM: GPU 0000:01:00.0: rm_init_adapter failed, device minor number 0
    # Aug 28 12:21:11 aol kernel: [drm:nv_drm_dev_load [nvidia_drm]] *ERROR* [nvidia-drm] [GPU ID 0x00000100] Failed to allocate NvKmsKapiDevice
    # Aug 28 12:21:40 aol kernel: NVRM: GPU 0000:01:00.0: RmInitAdapter failed! (0x62:0x56:2830)
    # Aug 28 12:21:40 aol kernel: NVRM: GPU 0000:01:00.0: rm_init_adapter failed, device minor number 0
    # Aug 28 12:21:40 aol kernel: NVRM: GPU 0000:01:00.0: RmInitAdapter failed! (0x62:0x56:2830)
    # Aug 28 12:21:40 aol kernel: NVRM: GPU 0000:01:00.0: rm_init_adapter failed, device minor number 0
    # Aug 28 12:21:40 aol kernel: NVRM: GPU 0000:01:00.0: RmInitAdapter failed! (0x62:0x56:2830)
    # Aug 28 12:21:40 aol kernel: NVRM: GPU 0000:01:00.0: rm_init_adapter failed, device minor number 0
    # Aug 28 12:21:48 aol kernel: NVRM: GPU 0000:01:00.0: RmInitAdapter failed! (0x62:0x56:2830)
    # Aug 28 12:21:48 aol kernel: NVRM: GPU 0000:01:00.0: rm_init_adapter failed, device minor number 0
    # Aug 28 12:49:57 aol sudo[4614]:        e : TTY=pts/2 ; PWD=/home/e/Workspace/infra ; USER=root ; COMMAND=/nix/store/5kcc5rnag7yymmsr6yqs7993xpdqs62w-coreutils-9.11/bin/env LC_ALL=en_US.UTF-8 nvidia-bug-report.sh
    # Aug 28 12:49:58 aol kernel: NVRM: GPU 0000:01:00.0: RmInitAdapter failed! (0x62:0x56:2830)
    # Aug 28 12:49:58 aol kernel: NVRM: GPU 0000:01:00.0: rm_init_adapter failed, device minor number 0
    # Aug 28 12:49:59 aol kernel: NVRM: GPU 0000:01:00.0: RmInitAdapter failed! (0x62:0x56:2830)
    # Aug 28 12:49:59 aol kernel: NVRM: GPU 0000:01:00.0: rm_init_adapter failed, device minor number 0
    disable = true;
  };
  prefs.kernel = {
    params = [ "NVreg_EnableGspFirmware=0" ];
  };
  prefs.ssh = {
    enableTpmAgent = true;
  };
  prefs.sing-box.enable = true;
  prefs.ap = {
    enable = true;
    settings = {
      SSID = "Lord of the Pings";
      PASSPHRASE = "YouShallNotPass!!!";
      INTERNET_IFACE = "wlan0";
      WIFI_IFACE = "wlan0";
    };
  };
  prefs.tuned.extraExtremePowersaveRules = {
    # Automatically generated by powertop2tuned tool
    # sudo powertop --html=htmlfile.html
    # powertop2tuned --input htmlfile.html --output . --force
    audio = {
      # Energieverwaltung für Audiocodec aktivieren
      timeout = 1;
    };

    sysfs = {
      # AutoSuspend für USB-Gerät N-KEY Device [ASUSTeK Computer Inc.]
      "/sys/bus/usb/devices/3-9/power/control" = "auto";

      # Laufzeit-Energieverwaltung für PCI-Gerät Intel Corporation Platform Monitoring Technology
      "/sys/bus/pci/devices/0000:00:0a.0/power/control" = "auto";

      # Laufzeit-Energieverwaltung für PCI-Gerät Sandisk Corp WD SN560/SN740/SN770/SN5000 NVMe SSD
      "/sys/bus/pci/devices/10000:e1:00.0/power/control" = "auto";

      # Laufzeit-Energieverwaltung für PCI-Gerät Intel Corporation Volume Management Device NVMe RAID Controller
      "/sys/bus/pci/devices/0000:00:0e.0/power/control" = "auto";

      # Laufzeit-Energieverwaltung für PCI-Gerät Sandisk Corp WD SN560/SN740/SN770/SN5000 NVMe SSD
      "/sys/bus/pci/devices/10000:e2:00.0/power/control" = "auto";

      # Laufzeit-Energieverwaltung für PCI-Gerät Intel Corporation RST VMD Managed Controller
      "/sys/bus/pci/devices/0000:00:06.0/power/control" = "auto";

      # Laufzeit-Energieverwaltung für PCI-Gerät Realtek Semiconductor Co., Ltd. RTL8125 2.5GbE Controller
      "/sys/bus/pci/devices/0000:2c:00.0/power/control" = "auto";

      # Laufzeit-Energieverwaltung für PCI-Gerät Intel Corporation 12th Gen Core Processor Host Bridge/DRAM Registers
      "/sys/bus/pci/devices/0000:00:00.0/power/control" = "auto";

      # Wake-On-LAN-Status für Gerät eno2
      "/sys/class/net/eno2/device/power/wakeup" = "disabled";

      # Wake-On-LAN-Status für Gerät wlan0
      "/sys/class/net/wlan0/device/power/wakeup" = "disabled";

      # Wake status for USB device usb3
      "/sys/bus/usb/devices/usb3/power/wakeup" = "disabled";

      # Wake status for USB device usb1
      "/sys/bus/usb/devices/usb1/power/wakeup" = "disabled";

      # Wake status for USB device usb4
      "/sys/bus/usb/devices/usb4/power/wakeup" = "disabled";

      # Wake status for USB device 3-10
      "/sys/bus/usb/devices/3-10/power/wakeup" = "disabled";

      # Wake status for USB device usb2
      "/sys/bus/usb/devices/usb2/power/wakeup" = "disabled";
    };
  };
}
