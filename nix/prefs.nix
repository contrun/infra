{ ... }@args:
let
  fix =
    f:
    let
      x = f x;
    in
    x;
  extends =
    f: rattrs: self:
    let
      super = rattrs self;
    in
    super // f self super;

  inherit (import ./fixed-systems.nix) systems;

  prefFiles = [
    ./prefs.local.nix
    ./prefs.secret.nix
  ];

  pkgs = (
    args.pkgs or (builtins.throw "Forcing pkgs in prefs.nix without given in the input parameter")
  );

  hostname =
    args.hostname or (
      let
        # LC_CTYPE=C tr -dc 'a-z' < /dev/urandom | head -c3 | tee /tmp/hostname
        hostNameFiles =
          if builtins.pathExists "/tmp/nixos_bootstrap" then
            [
              /tmp/etc/hostname
              /mnt/etc/hostname
              /tmp/hostname
              /etc/hostname
            ]
          else
            [ /etc/hostname ];
        fs = builtins.filter (
          x:
          let
            e = builtins.pathExists x;
          in
          builtins.trace "hostname file ${x} exists? ${builtins.toString e}" e
        ) hostNameFiles;
        f = builtins.elemAt fs 0;
        c = builtins.readFile f;
        l = builtins.match "([[:alnum:]]+)[[:space:]]*" c;
        newHostname = builtins.elemAt l 0;
      in
      builtins.trace "obtained new hostname ${newHostname} from disk" newHostname
    );
  # printf "%s" "hostname: $HOST" | sha512sum | head -c 10
  hostId = builtins.substring 0 8 (builtins.hashString "sha512" "hostname: ${hostname}");

  default = self: {
    normalNodes = [
      "ssg"
      "jxt"
      "shl"
      "mdq"
      "dbx"
      "dvm"
      "aol"
    ];
    hostAliases =
      builtins.foldl' (acc: current: acc // { "${current}" = current; }) { } self.normalNodes
      // {
        hub = "mdq";
      };
    pkgsRelatedPrefs = {
      kernelPackages = pkgs.linuxPackages_latest;
      extraModulePackages = [
        # super.pkgsRelatedPrefs.rtl8188gu
      ];
      rtl8188gu = (self.pkgsRelatedPrefs.kernelPackages.callPackage ./hardware/rtl8188gu.nix { });
      extraUdevRules =
        let
          getOptionalRules = x: if (x.enable or true) then x.rules else [ ];
          fixedRules = [
            {
              rules = [
                # TPM
                ''
                  KERNEL=="tpm[0-9]*", MODE="0660", OWNER="wheel"
                  KERNEL=="tpmrm[0-9]*", MODE="0660", GROUP="wheel"
                ''

                ''
                  KERNEL=="uinput", GROUP="${self.ownerGroup}", MODE="0660", OPTIONS+="static_node=uinput"
                ''

                # canokeys
                ''
                  # GnuPG/pcsclite
                  SUBSYSTEM!="usb", GOTO="canokeys_rules_end"
                  ACTION!="add|change", GOTO="canokeys_rules_end"
                  ATTRS{idVendor}=="20a0", ATTRS{idProduct}=="42d4", ENV{ID_SMARTCARD_READER}="1"
                  LABEL="canokeys_rules_end"

                  # FIDO2/U2F
                  # note that if you find this line in 70-u2f.rules, you can ignore it
                  KERNEL=="hidraw*", SUBSYSTEM=="hidraw", ATTRS{idVendor}=="20a0", ATTRS{idProduct}=="42d4", TAG+="uaccess", GROUP="plugdev", MODE="0660"

                  # make this usb device accessible for users, used in WebUSB
                  # change the mode so unprivileged users can access it, insecure rule, though
                  SUBSYSTEMS=="usb", ATTR{idVendor}=="20a0", ATTR{idProduct}=="42d4", MODE:="0666"
                  # if the above works for WebUSB (web console), you may change into a more secure way
                  # choose one of the following rules
                  # note if you use "plugdev", make sure you have this group and the wanted user is in that group
                  #SUBSYSTEMS=="usb", ATTR{idVendor}=="20a0", ATTR{idProduct}=="42d4", GROUP="plugdev", MODE="0660"
                  #SUBSYSTEMS=="usb", ATTR{idVendor}=="20a0", ATTR{idProduct}=="42d4", TAG+="uaccess"
                ''
              ];
            }
          ];
          powerSavingRules = [
            {
              rules = [
                ''
                  SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="[0-50]", RUN+="${pkgs.bash}/bin/bash -c 'echo balance_power > /sys/devices/system/cpu/cpufreq/policy?/energy_performance_preference'"
                ''
              ];
            }
          ];
          systemdPowerSavingRules =
            builtins.map
              (
                x: with x; {
                  inherit enable;
                  rules = [
                    ''
                      SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="[0-95]", RUN+="${
                        if (x.userUnit or false) then "${pkgs.su}/bin/su ${self.owner} -c '" else ""
                      }${pkgs.systemd}/bin/systemctl stop ${unit}${if (x.userUnit or false) then " --user'" else ""}"
                      SUBSYSTEM=="power_supply", ATTR{status}=="Not charging", RUN+="${
                        if (x.userUnit or false) then "${pkgs.su}/bin/su ${self.owner} -c '" else ""
                      }${pkgs.systemd}/bin/systemctl start ${unit}${if (x.userUnit or false) then " --user'" else ""}"
                    ''
                  ];
                }
              )
              [
                {
                  enable = self.enablePromtail;
                  unit = "promtail";
                }
                {
                  enable = self.enablePrometheus;
                  unit = "prometheus";
                }
                {
                  enable = self.enableSyncthing;
                  unit = "syncthing";
                }
              ];
          rules =
            fixedRules
            ++ (if self.enablePowerSavingMode then (powerSavingRules ++ systemdPowerSavingRules) else [ ]);
          rulesList = builtins.foldl' (acc: current: acc ++ (getOptionalRules current)) [ ] rules;
        in
        builtins.concatStringsSep "\n" rulesList;
    };
    isLaptop = false;
    enableUpower = self.isLaptop;
    upowerCriticalPowerAction = "PowerOff";
    isMinimalSystem = true;
    isMaximalSystem = false;
    isHomeManagerOnly = false;
    homeManagerStateVersion = "21.05";
    systemStateVersion = "20.09";
    isVirtualMachine = builtins.match "(.*)vm$" self.hostname != null;
    enableAarch64Cross = false;
    isVagrantBox = false;
    owner = if self.isVagrantBox then "vagrant" else "e";
    ownerUid = 1000;
    ownerGroup = "users";
    ownerGroupGid = 100;
    enablePowerSavingMode = true;
    home = "/home/${self.owner}";
    defaultHome = "/home/${self.owner}";
    syncFolder = "${self.home}/Sync";
    nixosSystem = "x86_64-linux";
    getNixConfig = path: ./. + "/${path}";
    getDotfile = path: ./../home + "/${path}";
    helpersPath = self.getNixConfig "lib/mkHelpers.nix";
    videoDrivers = null;
    consoleFont = null;
    hostname = "hostname";
    hostId = "346b7a87";
    helpers = import self.helpersPath { lib = args.inputs.nixpkgs.lib; };
    edgeProxyHostnames = [
      "nrk"
      "pkn"
    ];
    enableSessionVariables = true;
    enableAllFirmware = !self.isMinimalSystem;
    enableRedistributableFirmware = !self.isMinimalSystem;
    enableGraphics = !self.isMinimalSystem;
    dpi = 144;
    enableHidpi = true;
    enableIPv6 = true;
    enableGenerationsDir = false;
    bootloader = "systemd";
    enableGrub = self.bootloader == "grub";
    enableWireguard = self.wireguardHostIndex != null;
    enableContainerWired = !self.isMinimalSystem;
    wireguardIPOffsetForNixosHosts = 51;
    wireguardHostIndex =
      let
        f =
          acc: e:
          acc
          // (
            let
              next = acc."__next__" or self.wireguardIPOffsetForNixosHosts;
            in
            {
              "${e}" = next;
              "__next__" = next + 1;
            }
          );
        l = builtins.foldl' f { } self.normalNodes;
        hostnameToIndex = builtins.removeAttrs l [ "__next__" ];
      in
      hostnameToIndex."${self.hostname}" or null;
    enableSystemdBoot = self.bootloader == "systemd";
    enableSystemdNetworkd = true;
    efiCanTouchEfiVariables = true;
    isRaspberryPi = false;
    networkController = if self.enableMicrovmGuest then "wpa_supplicant" else "iwd";
    enableSupplicant = self.networkController == "wpa_supplicant";
    enableWireless = self.enableSupplicant;
    enableIwd = self.networkController == "iwd";
    enableBumblebee = false;
    enableMediaKeys = true;
    # TODO: failed to build on microvm guest
    # error: access to canonical path '/nix/store/lz5pb4y9z79lc65asdx6j0wiicm3p12q-binutils-wrapper-2.35.2/nix-support/dynamic-linker' is forbidden in restricted mode
    enableNixLd = !self.enableMicrovmGuest;
    # TODO: enable microvm host failed with
    #    Failed assertions:
    #    - The security.wrappers.qemu-bridge-helper wrapper is not valid:
    #        setuid/setgid and capabilities are mutually exclusive.
    enableMicrovmHost = false;
    enableMicrovmGuest = false;
    microvmHostConfig = { };
    microvmGuestConfig = { };
    enabledMicroVmGuests = { };
    # cannot enable X11 forwarding without setting xauth location
    enableSshX11Forwarding = !self.isMinimalSystem && !self.enableMicrovmGuest;
    enableSshPortForwarding = true;
    dnsServers = [
      "1.0.0.1"
      "8.8.4.4"
      "9.9.9.9"
      "180.76.76.76"
      "223.5.5.5"
    ];
    enableResolved = true;
    enableFallbackAccount = false;
    enableTailScale = !self.isMinimalSystem;
    enableHomeManagerUnison = false;
    enableHomeManagerWayvnc = false;
    enableHomeManagerXdgPortal = false;
    enableHomeManagerRcloneBisync = false;
    enableHomeManagerRcloneSync = false;
    enableHomeManagerRcloneMount = false;
    enableHomeManagerRcloneServe = false;
    enableHomeManagerCloudflared = false;
    enableHomeManagerGost = false;
    enableHomeManagerTailScale = false;
    enableHomeManagerCaddy = false;
    enableHomeManagerCodeTunnel = false;
    enableHomeManagerJupyter = false;
    enableHomeManagerDufs = false;
    enableDebugInfo = false;
    enableBtrfs = false;
    enableZfs = !self.isMinimalSystem;
    enableSanoid = false;
    enableSyncoid = false;
    syncoidCommands = { };
    enableZfsUnstable = self.enableZfs;
    enableCrashDump = false;
    xWindowManager = if (self.nixosSystem == "x86_64-linux") then "xmonad" else "i3";
    xDefaultSession = "none+" + self.xWindowManager;
    enableKeyd = !self.isMinimalSystem;
    enableYdotool = !self.isMinimalSystem;
    enableXmonad = false && self.xWindowManager == "xmonad" && !self.isMinimalSystem;
    enableI3 = !self.isMinimalSystem;
    enableAwesome = !self.isMinimalSystem;
    enableSway = !self.isMinimalSystem;
    enableKdeConnect =
      !self.isMinimalSystem
      && (builtins.elem self.nixosSystem [
        "x86_64-linux"
        "aarch64-linux"
      ]);
    enableSwayForGreeted = self.enableSway;
    enablePamMount = !self.isMinimalSystem;
    enableYubico = !self.isMinimalSystem;
    enablePamU2f = !self.isMinimalSystem;
    enablePcscd = !self.isMinimalSystem;
    enableFontConfig = !self.isMinimalSystem;
    xSessionCommands = builtins.concatStringsSep "\n" ([
      ''
        dunst &
        # alacritty &
        kdeconnect-indicator &
        feh --bg-fill "$(shuf -n1 -e ~/Storage/wallpapers/*)" &
        # shadowsocksControl.sh restart 4 1 &
        # systemctl --user start syncthing &
        # systemctl --user start ddns &
        # sudo iw dev wlp2s0 set power_save off &
        # ibus-daemon -drx &
        copyq &
        # # libinput-gestures-setup start &
        # autoMount.sh &
        # startupHosts.sh &
      ''
    ]);
    # xSessionCommands = "";
    displayManager = if self.enableGreetd then null else "gdm";
    enableLightdm = self.displayManager == "lightdm";
    enableGdm = self.displayManager == "gdm";
    enableSddm = self.displayManager == "sddm";
    enableStartx = self.displayManager == "startx";
    installHomePackages = false;
    buildCores = 0;
    maxJobs = "auto";
    proxy = null;
    enableSingBox = !self.isMinimalSystem;
    myPath = [ "${self.home}/.bin" ];
    enableSyncthing = !self.isMinimalSystem && !self.enableHomeManagerSyncthing;
    # home-manager also manages syncthing, but has less options provided,
    # We use nixpkgs to manage syncthing when possible, home-manager otherwise.
    enableHomeManagerSyncthing = true;
    syncthingIgnores = [
      "roam/.emacs.d/straight"
      "roam/public"
    ];
    syncthingDevices =
      let
        default = {
          addresses = [
            "!10.144.0.0/16"
            "0.0.0.0/0"
            "::/0"
          ];
          introducer = false;
        };
      in
      builtins.mapAttrs (name: value: default // value) {
        ssg = {
          id = "B6UODTC-UKUQNJX-4PQBNBV-V4UVGVK-DS6FQB5-CXAQIRV-6RWH4UW-EU5W3QM";
        };
        shl = {
          id = "HOK7XKV-ZPCTMOV-IKROQ4D-CURZET4-XTL4PMB-HBFTJBX-K6YVCM2-YOUDNQN";
        };
        jxt = {
          id = "UYHCZZA-7M7LQS4-SPBWSMI-YRJJADQ-RUSBIB3-KEELCYG-QUYJIW2-R6MZGAQ";
        };
        mdq = {
          id = "MWL5UYZ-H2YT6WE-FK3XO5X-5QX573M-3H4EJVY-T2EJPHQ-GBLAJWD-PTYRLQ3";
          introducer = true;
        };
        gcv = {
          id = "X7QL3PP-FEKIMHT-BAVJIR5-YX77J26-42XWIJW-S5H2FCF-RIKRKB5-RU3XRAB";
        };
        ngk = {
          id = "OTM73BH-NPIJTKJ-3F57TCL-VNX26RO-VKW6S3M-2XTXNJC-AGPCWWQ-VO5V4AM";
        };
        mmms = {
          id = "K3UZTSW-DVAKHSF-E6Q3LFT-OTWDUDF-C3O7NEC-4A6XGJB-2LZYQFA-PMIRDQL";
        };
        aol = {
          id = "FSTAIDE-E6OUWEK-BAWARYB-T4MAXIU-RML2GS2-YLYAHJO-UBKWKBD-KQ3VLQO";
        };
        npo = {
          id = "NRV7EXF-JGP4GYO-2MRVGTS-CYWGISC-XBGRHYR-FCJ66UI-EGKILML-KAS2VAK";
        };
        eik = {
          id = "R5P4E2X-PQSJH7T-T2ZSKC4-XU2K2PK-WXWKLNZ-GZSXJ6C-IDMGHCZ-6TT7ZQ5";
        };
        wae = {
          id = "KXOCACZ-26VKKOO-3NRCLSH-EFRSQC2-VMKDJHE-ITD7NZN-POSZEDL-ZRUNRA6";
        };
      };
    enablePrometheus = false;
    enablePrometheusAgent = false;
    enablePrometheusExporters = !self.isMinimalSystem;
    enableSmartctlExporter = self.enablePrometheusExporters;
    smartctlExporterDevices = [ ];
    prometheusPort = 9001;
    enableLoki = false;
    lokiHttpPort = 3100;
    lokiGrpcPort = 9096;
    enablePromtail = false;
    promtailHttpPort = 28183;
    promtailGrpcPort = 0;
    enableRsyncd = false;
    enableMpd = false;
    enableFlatpak = false;
    enableXdgPortal = self.enableSway;
    enableXdgPortalWlr = self.enableSway;
    enableEmacs = !self.isMinimalSystem;
    enableLocate = false;
    enableFail2ban = true;
    enableSamba = !self.isMinimalSystem;
    enableVsftpd = !self.isMinimalSystem;
    enableWaydroid = false;
    buildMachines = [ ];
    distributedBuilds = true;
    enableResticBackup = !self.isMinimalSystem;
    enableResticPrune = self.enableResticBackup;
    enableXserver = !self.isMinimalSystem && self.displayManager != null;
    enableGreetd = true;
    enableSeatd = !self.isMinimalSystem;
    enableXautolock = self.enableXserver;
    enableGPGAgent = !self.isMinimalSystem;
    enableADB = self.nixosSystem == "x86_64-linux";
    syncFolders = {
      calibre = {
        path = "${self.home}/Storage/Calibre";
      };
      sync = {
        path = "${self.home}/Sync";
      };
      upload = {
        path = "${self.home}/Storage/Upload";
        type = "sendonly";
      };
    };
    enablePipewire = true;
    enableSlock = true;
    enableZSH = true;
    enableFish = false;
    enableJava = !self.isMinimalSystem;
    enableSysdig = false;
    enableCcache = true;
    enableFirewall = false;
    enableChrony = true;
    enableFcron = false;
    enableRedshift = false;
    enablePostfix = !self.isMinimalSystem;
    enableNfs = !self.isMinimalSystem;
    linkedJdks =
      if self.isMinimalSystem then
        [ "openjdk8" ]
      else
        [
          "openjdk21"
          "openjdk17"
          "openjdk8"
        ];
    enableNextcloudClient = false;
    enableTaskWarriorSync = !self.isMinimalSystem;
    enableVdirsyncer = !self.isMinimalSystem;
    enableDdns = !self.isMinimalSystem;
    enableWireshark = !self.isMinimalSystem;
    enableInputMethods = !self.isMinimalSystem;
    enabledInputMethod = "fcitx5";
    enableVirtualboxHost = !self.isMinimalSystem;
    enablePodman = !self.isMinimalSystem;
    replaceDockerWithPodman = self.isMinimalSystem;
    enableLibvirtd = !self.isMinimalSystem;
    enableUdisks2 = !self.isMinimalSystem;
    enableAvahi = !self.isMinimalSystem;
    avahiHostname = self.hostname;
    enablePrinting = !self.isMinimalSystem;
    enableBluetooth = true;
    enableAcpilight = true;
    enableThermald = false;
    enableAutoUpgrade = true;
    autoUpgradeChannel = "https://nixos.org/channels/nixos-unstable";
    enableAutoLogin = true;
    enableLibInput = true;
    enableFprintd = !self.isMinimalSystem;
    enableBootSSH = true;
    authorizedKeys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCkLov3pXODoOtXhJqilCqD66wR9y38LgWm8bCwCrZPJQzsjhZ0IsyoTf5Ph6UJ73BWuyzN6KWz58cbsK1MWlAT0UA7CBtISfv+KU2k2MWMk4u+ylE0l+1eThkLE0DfvJRh4TXHrTM0aDWBzgZvtYgcydy9e1FMrIXmKp+DoTPy2WC8NS0gmOSiDwgZAjJy67Ic0uJHqvr1qPSkXqtiXywhVTC6wt/EJJOTv+g6LucpelfC3wXgtADb6p/Wxa5Et6QU3UgpeSoMke3yk6vNEIxtPiatXDMDURmmkFdxdVh6ts9Jh5aC04lZE1A/gTUTNBKdFapxgglzqDg3cg/utNlx"
    ];
    privilegedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL9rXlWqIfjVL5fB2kVzN0SQO472HzUugvZGa7Q/MLk2 root@all"
    ];
    enableGnomeKeyring = false;
    emulatedSystems =
      if (self.nixosSystem == "x86_64-linux") then
        [
          "aarch64-linux"
          "riscv64-linux"
        ]
      else
        [ ];
    extraModulePackages = [ ];
    kernelPatches = [ ];
    kernelParams = [ "boot.shell_on_fail" ];
    blacklistedKernelModules = [ ];
    initrdAvailableKernelModules = [ ];
    initrdKernelModules = [
      "usbnet"
      "cdc_ether"
      "rndis_host"
    ];
    kernelModules = [
      # For the sysctl net.bridge.bridge-nf-call-* options to work
      "br_netfilter"
    ];
    kernelSysctl = {
      "fs.file-max" = 131071;
      "net.core.rmem_max" = 67108864;
      "net.core.wmem_max" = 67108864;
      "net.core.netdev_max_backlog" = 250000;
      "net.core.somaxconn" = 4096;
      "net.core.default_qdisc" = "fq";
      "net.ipv4.tcp_syncookies" = 1;
      "net.ipv4.tcp_tw_reuse" = 1;
      "net.ipv4.tcp_fin_timeout" = 30;
      "net.ipv4.tcp_keepalive_time" = 1200;
      "net.ipv4.ip_local_port_range" = "10000 65000";
      "net.ipv4.tcp_max_syn_backlog" = 8192;
      "net.ipv4.tcp_max_tw_buckets" = 5000;
      "net.ipv4.tcp_fastopen" = 3;
      "net.ipv4.tcp_mem" = "25600 51200 102400";
      "net.ipv4.tcp_rmem" = "4096 87380 67108864";
      "net.ipv4.tcp_wmem" = "4096 65536 67108864";
      "net.ipv4.tcp_mtu_probing" = 1;
      "net.ipv4.tcp_congestion_control" = "bbr";
      # https://github.com/springzfx/cgproxy/blob/aaa628a76b2911018fc93b2e3276c177e85e0861/readme.md#known-issues
      # Transparent proxy does not work with these options on.
      # See also https://linuxconfig.org/how-to-use-bridged-networking-with-libvirt-and-kvm
      # See also https://wiki.libvirt.org/page/Net.bridge.bridge-nf-call_and_sysctl.conf
      "net.bridge.bridge-nf-call-arptables" = 0;
      "net.bridge.bridge-nf-call-ip6tables" = 0;
      "net.bridge.bridge-nf-call-iptables" = 0;
      "vfs.usermount" = 1;
      "net.ipv4.igmp_max_memberships" = 256;
      "fs.inotify.max_user_instances" = 256;
      "fs.inotify.max_user_watches" = 524288;
      "kernel.kptr_restrict" = 0;
      "kernel.perf_event_paranoid" = 1;
      "net.ipv4.conf.all.route_localnet" = 1;
      "net.ipv4.conf.default.route_localnet" = 1;
    }
    // (
      if self.enablePowerSavingMode then
        {
          # See https://wiki.archlinux.org/title/Power_management
          "kernel.nmi_watchdog" = 0;
          "vm.laptop_mode" = 5;
          "vm.dirty_writeback_centisecs" = 1500;
        }
      else
        { }
    );
    networkingInterfaces = { };
    nixosStableVersion = "20.09";
    enableUnstableNixosChannel = false;
    nixosAutoUpgrade = {
      nixosChannelList = [
        "stable"
        "unstable"
        "unstable-small"
      ];
      homeManagerChannel = "https://github.com/rycee/home-manager/archive/master.tar.gz";
      enableHomeManager = true;
      updateMyPackages = true;
      allowReboot = false;
      nixosRebuildFlags = [ ];
      onCalendar = "04:30";
    };
    extraOutputsToInstall = [ ];
  };

  hostSpecific =
    self: super:
    {
      inherit hostname hostId;
    }
    // (
      if hostname == "default" then
        {
          isMinimalSystem = true;
        }
      else if systems ? "${hostname}" then
        let
          nixosSystem = systems."${hostname}";
          isForCiCd = builtins.match "cicd-(.*)" hostname != null;
          # Always enable everything to build fairly large packages.
          isMaximal = builtins.match "maximal-(.*)" hostname != null;
        in
        (
          {
            inherit nixosSystem;
            isMinimalSystem = true;
          }
          // (
            if isForCiCd then
              {
                enableEmacs = true;
              }
              // (
                if nixosSystem == "x86_64-linux" then
                  {
                    enableVirtualboxHost = true;
                  }
                else if nixosSystem == "aarch64-linux" then
                  {
                    installHomePackages = false; # Building aarch64 on qemu is too slow to be of any use.
                  }
                else
                  { }
              )
            else
              { }
          )
          // (
            if isMaximal then
              {
                isMaximalSystem = true;
                isMinimalSystem = false;
                enablePrometheus = true;
                enablePromtail = true;
                enableVirtualboxHost = true;
                enableZerotierone = true;
                enableEmacs = true;
              }
            else
              { }
          )
        )
      else if hostname == "uzq" then
        {
          enableHidpi = true;
          pkgsRelatedPrefs = super.pkgsRelatedPrefs // {
            consoleFont = "${pkgs.terminus_font}/share/consolefonts/ter-g20n.psf.gz";
          };
          hostId = "80d17333";
          enableX2goServer = true;
          # kernelPatches = [{
          #   # See https://github.com/NixOS/nixpkgs/issues/91367
          #   name = "anbox-kernel-config";
          #   patch = null;
          #   extraConfig = ''
          #     CONFIG_ASHMEM=y
          #     CONFIG_ANDROID=y
          #     CONFIG_ANDROID_BINDER_IPC=y
          #     CONFIG_ANDROID_BINDERFS=y
          #     CONFIG_ANDROID_BINDER_DEVICES="binder,hwbinder,vndbinder"
          #   '';
          # }];
        }
      else if hostname == "dbx" then
        {
          isMinimalSystem = true;
          isVagrantBox = true;
          pkgsRelatedPrefs = super.pkgsRelatedPrefs // {
            kernelPackages = pkgs.linuxPackages;
          };
        }
      else if hostname == "adx" then
        {
          isMinimalSystem = false;
          isVagrantBox = true;
          enableHomeManagerSyncthing = true;
        }
      else if hostname == "dvm" then
        {
          isMinimalSystem = true;
          enableMicrovmGuest = true;
          microvmGuestConfig = {
            volumes = [
              {
                mountPoint = "/var";
                image = "var.img";
                size = 10 * 1024;
              }
            ];
            shares = [
              {
                # use "virtiofs" for MicroVMs that are started by systemd
                proto = "9p";
                tag = "ro-store";
                # a host's /nix/store will be picked up so that the
                # size of the /dev/vda can be reduced.
                source = "/nix/store";
                mountPoint = "/nix/.ro-store";
              }
            ];
            socket = "control.socket";
            # relevant for delarative MicroVM management
            hypervisor = "qemu";
            vcpu = 4;
            mem = 4 * 1024;
          };
        }
      else if hostname == "dqe" then
        {
          isMinimalSystem = true;
        }
      else if hostname == "ssg" then
        {
          isMinimalSystem = false;
          hostId = "b6653e48";
          systemStateVersion = "21.05";
          dpi = 128;
          enableX2goServer = true;
          enableHidpi = false;
          maxJobs = 6;
          smartctlExporterDevices = [ "/dev/nvme0n1" ];
          enableCfssl = true;
          enablePrometheus = true;
          enablePromtail = true;
          enableWireless = true;
          pkgsRelatedPrefs = super.pkgsRelatedPrefs // {
            consoleFont = "${pkgs.terminus_font}/share/consolefonts/ter-g20n.psf.gz";
          };
        }
      else if hostname == "jxt" then
        {
          isMinimalSystem = false;
          hostId = "5ee92b8d";
          smartctlExporterDevices = [ "/dev/nvme0n1" ];
          enableNetworkWatchdog = true;
          enablePrometheus = true;
          enablePromtail = true;
          enablePrinting = false;
          enableEternalTerminal = false;
          enableZerotierone = false;
          dnsServers = [
            "10.10.61.128"
            "10.10.61.129"
          ];
        }
      else if hostname == "shl" then
        {
          enableXserver = false;
          installHomePackages = false; # Too slow.
          kernelParams = super.kernelParams ++ [
            "cgroup_enable=cpuset"
            "cgroup_enable=memory"
            "cgroup_memory=1"
          ];
          nixosSystem = "aarch64-linux";
          isMinimalSystem = true;
          hostId = "6fce2459";
          pkgsRelatedPrefs = super.pkgsRelatedPrefs // {
            kernelPackages = pkgs.linuxPackages_rpi4;
          };
          enableZerotierone = false;
          enableTailScale = false;
          enableVirtualboxHost = false;
          isRaspberryPi = true;
          raspberryPiVersion = 4;
          enableVsftpd = false;
        }
      else if hostname == "gcv" then
        {
          nixosSystem = "x86_64-darwin";
        }
      else if hostname == "mdq" then
        {
          isMinimalSystem = false;
          useLargePackages = false;
          hostId = "59b352bc";
          dpi = 128;
          xWindowManager = "i3";
          enableAllFirmware = false;
          enableCalibreServer = true;
          linkedJdks = [ "openjdk8" ];
          enableEmacs = false;
          smartctlExporterDevices = [
            "/dev/sda"
            "/dev/sdb"
          ];
          enableNetworkWatchdog = true;
          enableSyncoid = true;
          syncFolders = super.syncFolders // {
            upload = {
              path = "${self.home}/Storage/Upload";
              type = "sendreceive";
            };
            camera = {
              path = "${self.home}/Storage/Camera";
              type = "sendreceive";
            };
          };
          syncoidCommands =
            let
              sendOptions = "-v";
              recvOptions = "-v";
            in
            {
              home = {
                inherit sendOptions recvOptions;
                source = "tank/HOME/home";
                target = "bpool/HOME/${self.hostname}";
              };
              var = {
                inherit sendOptions recvOptions;
                source = "tank/VAR/var";
                target = "bpool/VAR/${self.hostname}";
              };
            };
          sanoidDatasets = {
            "tank/HOME/home" = {
              autoprune = true;
              autosnap = true;
              daily = 7;
              hourly = 24;
              monthly = 1;
              yearly = 1;
              extraArgs = [
                "--verbose"
                "--readonly"
                "--debug"
              ];
            };
            "tank/VAR/var" = {
              autoprune = true;
              autosnap = true;
              daily = 7;
              hourly = 24;
              monthly = 1;
              yearly = 1;
              extraArgs = [
                "--verbose"
                "--readonly"
                "--debug"
              ];
            };
          };
          enablePrometheus = true;
          enablePromtail = true;
          initrdKernelModules = super.initrdKernelModules ++ [ "r8169" ];
          pkgsRelatedPrefs =
            super.pkgsRelatedPrefs
            // (with super.pkgsRelatedPrefs; {
              extraModulePackages = extraModulePackages ++ [ kernelPackages.rtl88x2bu ];
              consoleFont = "${pkgs.terminus_font}/share/consolefonts/ter-g20n.psf.gz";
              extraUdevRules =
                let
                  name = "rfkill-wrapper";
                  application =
                    with pkgs;
                    writeShellApplication {
                      inherit name;
                      text = ''
                        action="$1"
                        device_name="$2"
                        id="$(rfkill --output-all | grep -Po "([0-9]+)(?=.*$device_name)")"
                        rfkill "$action" "$id"
                      '';
                      runtimeInputs = [
                        util-linux
                        coreutils
                      ];
                    };
                  wrapper = "${application}/bin/${name}";
                  internalWirelessDevice = "acer-wireless";
                in
                builtins.concatStringsSep "\n" [
                  extraUdevRules
                  # Internal wireless card "acer-wireless" seems to be defunct
                  ''
                    ACTION=="remove", SUBSYSTEM=="usb", ENV{ID_VENDOR_ID}=="0b05", ENV{ID_MODEL_ID}=="1841", RUN+="${wrapper} unblock ${internalWirelessDevice}"
                    ACTION=="add", SUBSYSTEM=="usb", ENV{ID_VENDOR_ID}=="0b05", ENV{ID_MODEL_ID}=="1841", RUN+="${wrapper} block ${internalWirelessDevice}"
                  ''
                ];
            });
        }
      else if hostname == "zklab-5" then
        {
          home = "/home/contrun";
          isMinimalSystem = false;
          installHomePackages = true;
          enableHomeManagerCaddy = true;
          enableHomeManagerTailScale = true;
          enableHomeManagerCodeTunnel = true;
          enableHomeManagerDufs = true;
          enableHomeManagerWayvnc = true;
          enableHomeManagerXdgPortal = true;
          enableHomeManagerCloudflared = true;
          enableHomeManagerGost = true;
          enableHomeManagerJupyter = true;
        }
      else if hostname == "humpback" then
        {
          home = "/home/contrun";
          isMinimalSystem = false;
          installHomePackages = true;
          enableHomeManagerCaddy = true;
          enableHomeManagerTailScale = true;
          enableHomeManagerCodeTunnel = true;
          enableHomeManagerDufs = true;
          enableHomeManagerWayvnc = true;
          enableHomeManagerXdgPortal = true;
          enableHomeManagerCloudflared = true;
          enableHomeManagerGost = true;
          enableHomeManagerJupyter = true;
        }
      else if hostname == "aol" then
        {
          isLaptop = true;
          isMinimalSystem = false;
          hostId = "85d4bfd4";
          systemStateVersion = "22.05";
          homeManagerStateVersion = "22.05";
          installHomePackages = true;
          enableGlusterfs = false;
          enablePrometheus = false;
          enablePrometheusAgent = false;
          enablePrometheusExporters = false;
          enableCadvisor = false;
          enablePromtail = false;
          enableWaydroid = true;
          enableEternalTerminal = false;
          enableTtyd = false;
          enableWireguard = false;
          enableContainerWired = false;
          enableFallbackAccount = true;
          enableMicrovmHost = true;
          enabledMicroVmGuests = {
            # graphics = { };
          };
          enableHomeManagerUnison = true;
          enableHomeManagerRcloneBisync = true;
          enableHomeManagerRcloneSync = true;
          enableHomeManagerRcloneMount = true;
          enableHomeManagerRcloneServe = true;
          pkgsRelatedPrefs = super.pkgsRelatedPrefs // {
            kernelPackages = pkgs.linuxPackages_6_18;
          };
        }
      else if hostname == "madbox" then
        {
          isMinimalSystem = true;
          isHomeManagerOnly = true;
          enableHomeManagerSyncthing = true;
        }
      else
        {
          isMinimalSystem = true;
        }
    );

  overrides = builtins.map (path: (import (builtins.toPath path))) (
    builtins.filter (x: builtins.pathExists x) prefFiles
  );

  unevaluated = fix (
    builtins.foldl' (acc: override: extends override acc) default ([ hostSpecific ] ++ overrides)
  );
  pkgsRelatedPrefs = unevaluated.pkgsRelatedPrefs;
  notPkgsRelatedPrefs =
    let
      p = builtins.removeAttrs unevaluated [ "pkgsRelatedPrefs" ];
    in
    builtins.deepSeq p p;
  final = notPkgsRelatedPrefs // pkgsRelatedPrefs;
in
{
  pure = notPkgsRelatedPrefs;
  pkgsRelated = pkgsRelatedPrefs;
  all = final;
}
