let
  internalGetSubDomain = prefix: domain:
    if prefix == "" then domain else "${prefix}.${domain}";
in
{ ... }@args:
let
  fix = f: let x = f x; in x;
  extends = f: rattrs: self: let super = rattrs self; in super // f self super;

  inherit (import ./fixed-systems.nix) systems;

  prefFiles = [ ./prefs.local.nix ./prefs.secret.nix ];

  # NOTE: pkgs should not be forced unless we are sure pkgs == args.pkgs
  # This file is shared between flake.nix which generates a minimal host-specific nixos configuration and
  # common.nix which generates a more complete host-specific configuration.
  # When called from flake.nix, there will be no pkgs argument given. We must make sure pkgs is not forced by then.
  hasPkgs = args ? pkgs;
  hasInputs = args ? inputs;
  hasHostname = args ? hostname;
  pkgs = (
    args.pkgs or (builtins.throw
      "Forcing pkgs in prefs.nix without given in the input parameter")
  );

  hostname = args.hostname or (
    let
      # LC_CTYPE=C tr -dc 'a-z' < /dev/urandom | head -c3 | tee /tmp/hostname
      hostNameFiles =
        if builtins.pathExists "/tmp/nixos_bootstrap" then [
          /tmp/etc/hostname
          /mnt/etc/hostname
          /tmp/hostname
          /etc/hostname
        ] else
          [ /etc/hostname ];
      fs = builtins.filter
        (x:
          let e = builtins.pathExists x;
          in builtins.trace "hostname file ${x} exists? ${builtins.toString e}" e)
        hostNameFiles;
      f = builtins.elemAt fs 0;
      c = builtins.readFile f;
      l = builtins.match "([[:alnum:]]+)[[:space:]]*" c;
      newHostname = builtins.elemAt l 0;
    in
    builtins.trace "obtained new hostname ${newHostname} from disk"
      newHostname
  );
  # printf "%s" "hostname: $HOST" | sha512sum | head -c 10
  hostId = builtins.substring 0 8
    (builtins.hashString "sha512" "hostname: ${hostname}");

  default = self: {
    normalNodes = [ "ssg" "jxt" "shl" "mdq" "dbx" "dvm" "aol" ];
    hostAliases =
      builtins.foldl' (acc: current: acc // { "${current}" = current; }) { }
        self.normalNodes // {
        hub = "mdq";
      };
    pkgsRelatedPrefs = rec {
      kernelPackages = if self.enableZfsUnstable then pkgs.zfsUnstable.latestCompatibleLinuxPackages else if self.enableZfs then pkgs.zfs.latestCompatibleLinuxPackages else pkgs.linuxPackages_latest;
      extraModulePackages = [
        # super.pkgsRelatedPrefs.rtl8188gu
      ];
      rtl8188gu = (self.pkgsRelatedPrefs.kernelPackages.callPackage
        ./hardware/rtl8188gu.nix
        { });
      extraUdevRules =
        let
          getOptionalRules = x: if (x.enable or true) then x.rules else [ ];
          fixedRules = [{
            rules = [
              # Automatically shutdown on battery low.
              ''
                SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="[0-10]", RUN+="${pkgs.systemd}/bin/systemctl poweroff"
              ''

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
          }];
          powerSavingRules = [{
            rules = [
              ''
                SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="[0-50]", RUN+="${pkgs.bash}/bin/bash -c 'echo balance_power > /sys/devices/system/cpu/cpufreq/policy?/energy_performance_preference'"
              ''
            ];
          }];
          systemdPowerSavingRules = builtins.map
            (x: with x; {
              inherit enable;
              rules = [
                ''
                  SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="[0-95]", RUN+="${if (x.userUnit or false) then "${pkgs.su}/bin/su ${self.owner} -c '" else ""}${pkgs.systemd}/bin/systemctl stop ${unit}${if (x.userUnit or false) then " --user'" else ""}"
                  SUBSYSTEM=="power_supply", ATTR{status}=="Not charging", RUN+="${if (x.userUnit or false) then "${pkgs.su}/bin/su ${self.owner} -c '" else ""}${pkgs.systemd}/bin/systemctl start ${unit}${if (x.userUnit or false) then " --user'" else ""}"
                ''
              ];
            }) [
            {
              enable = self.enablePromtail;
              unit = "promtail";
            }
            {
              enable = self.enablePrometheus;
              unit = "prometheus";
            }
            {
              enable = self.enableCadvisor;
              unit = "cadvisor";
            }
            {
              enable = self.enableSyncthing;
              unit = "syncthing";
            }
            {
              enable = self.enableOfflineimap;
              userUnit = true;
              unit = "syncthing";
            }
          ];
          rules = fixedRules ++ (if self.enablePowerSavingMode then (powerSavingRules ++ systemdPowerSavingRules) else [ ]);
          rulesList = builtins.foldl' (acc: current: acc ++ (getOptionalRules current)) [ ] rules;
        in
        builtins.concatStringsSep "\n" rulesList;
    };
    isMinimalSystem = true;
    isMaximalSystem = false;
    isHomeManagerOnly = false;
    homeManagerStateVersion = "21.05";
    systemStateVersion = "20.09";
    useLargePackages = !self.isMinimalSystem;
    isVirtualMachine = builtins.match "(.*)vm$" self.hostname != null;
    enableAarch64Cross = false;
    isVagrantBox = false;
    owner = if self.isVagrantBox then "vagrant" else "e";
    ownerUid = 1000;
    ownerGroup = "users";
    ownerGroupGid = 100;
    noproxyGroup = "noproxy";
    enablePowerSavingMode = true;
    home = "/home/${self.owner}";
    syncFolder = "${self.home}/Sync";
    nixosSystem = "x86_64-linux";
    getNixConfig = path: ./. + "/${path}";
    getDotfile = args.inputs.dotfiles.getDotfile;
    helpersPath = self.getNixConfig "lib/mkHelpers.nix";
    videoDrivers = null;
    enableNvidiaPrimeConfig = false;
    enableNvidiaModesetting = false;
    enableNvidiaPowerManagement = false;
    enableNvidiaPowerManagementFinegrained = false;
    consoleFont = null;
    hostname = "hostname";
    hostId = "346b7a87";
    helpers = import self.helpersPath { lib = args.inputs.nixpkgs.lib; };
    edgeProxyHostnames = [ "nrk" "pkn" ];
    autosshDynamicPortOffset = 1090;
    autosshServers = with args.inputs.nixpkgs.lib;
      let
        configFiles = [ "${self.home}/.ssh/config" ];
        goodConfigFiles =
          builtins.filter (x: builtins.pathExists x) configFiles;
        lines = builtins.foldl' (a: e: a ++ (splitString "\n" (readFile e))) [ ]
          goodConfigFiles;
        autosshLines = filter (x: hasPrefix "Host autossh" x) lines;
        servers = map (x: removePrefix "Host " x) autosshLines;
      in
      filter (x: x != "autossh") servers;
    enableSessionVariables = true;
    enableAllFirmware = !self.isMinimalSystem;
    enableRedistributableFirmware = !self.isMinimalSystem;
    enableOpengl = !self.isMinimalSystem;
    dpi = 144;
    enableHidpi = true;
    enableIPv6 = true;
    enableGenerationsDir = false;
    bootloader = "systemd";
    enableGrub = self.bootloader == "grub";
    enableWireguard = self.wireguardHostIndex != null;
    wireguardIPOffsetForNixosHosts = 51;
    wireguardHostIndex =
      let
        f = acc: e: acc //
          (
            let next = acc."__next__" or self.wireguardIPOffsetForNixosHosts; in
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
    enableRaspberryPiBoot = self.bootloader == "raspberrypi";
    efiCanTouchEfiVariables = true;
    isRaspberryPi = false;
    networkController = if self.enableMicrovmGuest then "wpa_supplicant" else "iwd";
    enableSupplicant = self.networkController == "wpa_supplicant";
    enableWireless = self.enableSupplicant;
    enableIwd = self.networkController == "iwd";
    enableConnman = self.networkController == "connman";
    connmanBackend = "wpa_supplicant";
    connmanExtraConfig = ''
      AllowHostnameUpdates=false
      PersistentTetheringMode=true
    '';
    connmanExtraFlags = [ "--nodnsproxy" ];
    connmanNetworkInterfaceBlacklist = [ "vmnet" "vboxnet" "virbr" "ifb" "ve" "tailscale" "zt" "wg" "docker" "br-" ];
    enableBumblebee = false;
    enableMediaKeys = true;
    enableEternalTerminal = !self.isMinimalSystem;
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
    # cannot enable X11 forwarding without setting xauth location
    enableSshX11Forwarding = !self.isMinimalSystem && !self.enableMicrovmGuest;
    enableSshPortForwarding = true;
    dnsServers = [ "1.0.0.1" "8.8.4.4" "9.9.9.9" "180.76.76.76" "223.5.5.5" ];
    enableResolved = true;
    enableCoredns = !self.isMinimalSystem;
    enableCorednsForResolved = self.enableCoredns;
    corednsPort = 5322;
    enableSmartdns = false;
    enableUrxvtd = !self.isMinimalSystem;
    enablePrivoxy = false;
    enableFallbackAccount = false;
    buildZerotierone = !self.isMinimalSystem;
    enableZerotierone = self.buildZerotierone;
    zerotieroneNetworks = [ "9bee8941b5ce6172" ];
    smartdnsSettings = {
      bind = ":5533 -no-rule -group example";
      cache-size = 4096;
      server = [ "180.76.76.76" "223.5.5.5" ] ++ [ "9.9.9.9" ]
        ++ [ "192.0.2.2:53" ];
      server-tls = [ "8.8.8.8:853" "1.1.1.1:853" ];
      server-https =
        "https://cloudflare-dns.com/dns-query -exclude-default-group";
      prefetch-domain = true;
      speed-check-mode = "ping,tcp:80";
      log-level = "info";
    };
    enableCfssl = false;
    enableTtyd = !self.isMinimalSystem;
    enableSslh = false;
    enableWstunnel = !self.isMinimalSystem;
    wstunnelPort = 3275;
    sslhPort = 44443;
    enableAioproxy = !self.isMinimalSystem;
    aioproxyPort = 4443;
    enableTailScale = !self.isMinimalSystem;
    enableNetbird = !self.isMinimalSystem;
    enableX2goServer = false;
    enableDebugInfo = false;
    enableBtrfs = false;
    enableZfs = !self.isMinimalSystem;
    enableSanoid = false;
    enableSyncoid = false;
    syncoidCommands = { };
    enableZfsUnstable = self.enableZfs;
    enableCrashDump = false;
    enableDnsmasq = false;
    dnsmasqListenAddress = "127.0.0.233";
    dnsmasqResolveLocalQueries = false;
    dnsmasqExtraConfig = ''
      listen-address=${self.dnsmasqListenAddress}
      bind-interfaces
      cache-size=1000
    '';
    dnsmasqServers = [ "223.6.6.6" "180.76.76.76" "8.8.8.8" "9.9.9.9" ];
    enableArbtt = false;
    enableActivityWatch = false;
    enableAria2 = !self.isMinimalSystem;
    xWindowManager =
      if (self.nixosSystem == "x86_64-linux") then "xmonad" else "i3";
    xDefaultSession = "none+" + self.xWindowManager;
    enableKeyd = !self.isMinimalSystem;
    enableXmonad = false && self.xWindowManager == "xmonad" && !self.isMinimalSystem;
    enableI3 = !self.isMinimalSystem;
    enableAwesome = !self.isMinimalSystem;
    enableSway = !self.isMinimalSystem;
    enableKdeConnect = !self.isMinimalSystem && (builtins.elem self.nixosSystem [ "x86_64-linux" "aarch64-linux" ]);
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
    ] ++ (if self.enableActivityWatch then [
      ''
        aw-server &
        aw-watcher-afk &
        aw-watcher-window &
      ''
    ] else
      [ ]));
    # xSessionCommands = "";
    displayManager =
      if self.enableGreetd then null else "gdm";
    enableLightdm = self.displayManager == "lightdm";
    enableGdm = self.displayManager == "gdm";
    enableSddm = self.displayManager == "sddm";
    enableStartx = self.displayManager == "startx";
    installHomePackages = !self.isMinimalSystem;
    buildCores = 0;
    maxJobs = "auto";
    proxy = null;
    enableClashVerge = !self.isMinimalSystem;
    enableClashRedir = !self.enableClashVerge;
    enableClashRedirWatchdog = false;
    enableNetworkWatchdog = false;
    autoStartClashRedir = self.enableClashRedir;
    myPath = [ "${self.home}/.bin" ];
    enableOfflineimap = !self.isMinimalSystem;
    enableSyncthing = !self.isMinimalSystem;
    # home-manager also manages syncthing, but has less options provided,
    # We use nixpkgs to manage syncthing when possible, home-manager otherwise.
    enableHomeManagerSyncthing = false;
    syncthingIgnores = [ "roam/.emacs.d/straight" "roam/public" ];
    syncthingDevices =
      let
        default = { addresses = [ "!10.144.0.0/16" "0.0.0.0/0" "::/0" ]; introducer = false; };
      in
      builtins.mapAttrs (name: value: default // value)
        {
          ssg = {
            id =
              "B6UODTC-UKUQNJX-4PQBNBV-V4UVGVK-DS6FQB5-CXAQIRV-6RWH4UW-EU5W3QM";
          };
          shl = {
            id =
              "HOK7XKV-ZPCTMOV-IKROQ4D-CURZET4-XTL4PMB-HBFTJBX-K6YVCM2-YOUDNQN";
          };
          jxt = {
            id =
              "UYHCZZA-7M7LQS4-SPBWSMI-YRJJADQ-RUSBIB3-KEELCYG-QUYJIW2-R6MZGAQ";
          };
          mdq = {
            id =
              "MWL5UYZ-H2YT6WE-FK3XO5X-5QX573M-3H4EJVY-T2EJPHQ-GBLAJWD-PTYRLQ3";
            introducer = true;
          };
          gcv = {
            id =
              "X7QL3PP-FEKIMHT-BAVJIR5-YX77J26-42XWIJW-S5H2FCF-RIKRKB5-RU3XRAB";
          };
          ngk = {
            id =
              "OTM73BH-NPIJTKJ-3F57TCL-VNX26RO-VKW6S3M-2XTXNJC-AGPCWWQ-VO5V4AM";
          };
          mmms = { id = "K3UZTSW-DVAKHSF-E6Q3LFT-OTWDUDF-C3O7NEC-4A6XGJB-2LZYQFA-PMIRDQL"; };
          aol = { id = "FSTAIDE-E6OUWEK-BAWARYB-T4MAXIU-RML2GS2-YLYAHJO-UBKWKBD-KQ3VLQO"; };
          npo = { id = "NRV7EXF-JGP4GYO-2MRVGTS-CYWGISC-XBGRHYR-FCJ66UI-EGKILML-KAS2VAK"; };
          eik = { id = "R5P4E2X-PQSJH7T-T2ZSKC4-XU2K2PK-WXWKLNZ-GZSXJ6C-IDMGHCZ-6TT7ZQ5"; };
          wae = { id = "KXOCACZ-26VKKOO-3NRCLSH-EFRSQC2-VMKDJHE-ITD7NZN-POSZEDL-ZRUNRA6"; };
        };
    yandexConfig = {
      directory = "${self.home}/Sync";
      excludes = "";
      user = self.owner;
    };
    acmeEmail =
      if self.mainDomain == "" then
        "tobeoverridden@example.com"
      else
        "webmaster@${self.mainDomain}";
    domainPrefixes =
      let
        originalPrefix = (builtins.replaceStrings [ "_" ] [ "" ] self.hostname);
      in
      (if originalPrefix == self.hostAliases.hub then [ "hub" ] else [ ])
      ++ [ originalPrefix "local" ];
    domainPrefix = builtins.elemAt self.domainPrefixes 0;
    domains = builtins.map (prefix: internalGetSubDomain prefix self.mainDomain)
      self.domainPrefixes;
    domain = internalGetSubDomain self.domainPrefix self.mainDomain;
    getFullDomainName = x: internalGetSubDomain x self.domain;
    getFullDomainNames = prefix:
      builtins.map (domain: internalGetSubDomain prefix domain) self.domains;
    mainDomain = "cont.run";
    enableAcme = self.enableTraefik;
    acmeCerts =
      if self.enableAcme then {
        "${self.mainDomain}" = {
          domain = self.mainDomain;
          extraDomainNames =
            [ "*.${self.mainDomain}" "*.local.${self.mainDomain}" ]
            ++ (self.getFullDomainNames "*");
          # May spurious dns propagation failures.
          # dnsPropagationCheck = false;
          dnsProvider = "cloudflare";
          dnsResolver = "223.6.6.6:53";
          credentialsFile = "/run/secrets/acme-env";
        };
      } else
        { };
    enableYandexDisk = false;
    yandexExcludedDirs =
      [ "docs/org-mode/roam/.emacs.d" "ltximg" ".stversions" ".stfolder" ];
    enableTraefik = false;
    traefikMetricsPort = 8082;
    enableGrafana = false;
    grafanaPort = 2342;
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
    enableCadvisor = !self.isMinimalSystem;
    cadvisorPort = 28184;
    cadvisorExtraOptions = [ ];
    enablePostgresql = false;
    enableClickhouse = false;
    enableRedis = false;
    enableVsftpd = !self.isMinimalSystem;
    enableRsyncd = false;
    enableRcloneWebUI = !self.isMinimalSystem;
    enableMpd = false;
    enableAccountsDaemon = !self.isMinimalSystem;
    enableFlatpak = false;
    enableXdgPortal = self.enableSway;
    enableXdgPortalWlr = self.enableSway;
    enableJupyter = false;
    enableEmacs = !self.isMinimalSystem;
    enableLocate = false;
    enableFail2ban = true;
    davfs2Secrets = "${self.home}/.davfs2/secrets";
    enableDavfs2 = !self.isMinimalSystem;
    enableGlusterfs = !self.isMinimalSystem;
    enableSamba = !self.isMinimalSystem;
    enableContainerd = false;
    enableCrio = false;
    enableK3s = false;
    enableNomad = false;
    nomadSettings = {
      # A minimal config example:
      server = {
        enabled = true;
        bootstrap_expect = 1; # for demo; no fault tolerance
      };
      client = {
        enabled = true;
      };
    };
    enableConsul = false;
    consulInterface = "wg0";
    enableConsulWebUi = false;
    buildMachines = [ ];
    distributedBuilds = true;
    enableNextcloud = false;
    enableYandex = false;
    nextcloudWhere = "/nc/sync";
    enableCgroupAccounting = false;
    enableResticBackup = !self.isMinimalSystem;
    enableResticPrune = self.enableResticBackup;
    nextcloudContainerDataDirectory = "/var/data/nextcloud-data";
    ownerNextcloudContainerDataDirectory =
      "${self.nextcloudContainerDataDirectory}/${self.owner}/files";
    nextcloudWhat = "https://uuuuuu.ocloud.de/remote.php/webdav/sync/";
    yandexWhere = "${self.home}/yandex";
    yandexWhat = "https://webdav.yandex.com/sync/";
    enableXserver = !self.isMinimalSystem && self.displayManager != null;
    enableGreetd = true;
    enableXautolock = self.enableXserver;
    enableGPGAgent = !self.isMinimalSystem;
    # enableSmos = !self.isMinimalSystem && (self.nixosSystem == "x86_64-linux");
    enableSmos = false;
    enableAndroidDevEnv = false;
    enableSmosSync = self.enableSmos;
    enableFoot = !self.isMinimalSystem;
    enableSmosServer = false;
    enableADB = self.nixosSystem == "x86_64-linux";
    enableCalibreServer = false;
    calibreServerLibraries = [ self.syncFolders.calibre.path ];
    calibreServerPort = 8213;
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
    # Many packages depends on pulseaudio. If we set this to be false,
    # then we will have to build a ton of packages.
    enablePulseaudio = !self.enablePipewire;
    enableSlock = true;
    enableZSH = true;
    enableFish = false;
    enableJava = !self.isMinimalSystem;
    enableSysdig = false;
    enableCcache = true;
    enableFirewall = false;
    enableCompton = false;
    enableChrony = true;
    enableFcron = false;
    enableRedshift = false;
    enablePostfix = !self.isMinimalSystem;
    enableNfs = !self.isMinimalSystem;
    linkedJdks =
      if self.isMinimalSystem then
        [ "openjdk8" ]
      else [
        "openjdk21"
        "openjdk17"
        "openjdk8"
      ];
    enableNextcloudClient = false;
    enableTaskWarriorSync = !self.isMinimalSystem;
    enableVdirsyncer = !self.isMinimalSystem;
    enableHolePuncher = !self.isMinimalSystem;
    enableDdns = !self.isMinimalSystem;
    enableWireshark = !self.isMinimalSystem;
    enableInputMethods = !self.isMinimalSystem;
    enabledInputMethod = "fcitx5";
    enableVirtualboxHost = !self.isMinimalSystem;
    enableDocker = !self.replaceDockerWithPodman;
    enableDockerMetrics = self.enablePrometheusExporters && self.enableDocker;
    dockerMetricsPort = 9323;
    enablePodman = !self.isMinimalSystem;
    replaceDockerWithPodman = self.isMinimalSystem;
    enableLibvirtd = !self.isMinimalSystem;
    enableAnbox = false;
    enableUnifi = false;
    enableUdisks2 = !self.isMinimalSystem;
    enableAvahi = !self.isMinimalSystem;
    avahiHostname = self.hostname;
    enableGvfs = !self.isMinimalSystem;
    enableCodeServer = false;
    enablePrinting = !self.isMinimalSystem;
    enableBluetooth = true;
    enableAcpilight = true;
    enableThermald = false;
    enableAutoUpgrade = true;
    autoUpgradeChannel = "https://nixos.org/channels/nixos-unstable";
    enableAutossh = !self.isMinimalSystem;
    enableAutoLogin = true;
    enableLibInput = true;
    enableFprintd = !self.isMinimalSystem;
    enableBootSSH = true;
    authorizedKeys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQCkLov3pXODoOtXhJqilCqD66wR9y38LgWm8bCwCrZPJQzsjhZ0IsyoTf5Ph6UJ73BWuyzN6KWz58cbsK1MWlAT0UA7CBtISfv+KU2k2MWMk4u+ylE0l+1eThkLE0DfvJRh4TXHrTM0aDWBzgZvtYgcydy9e1FMrIXmKp+DoTPy2WC8NS0gmOSiDwgZAjJy67Ic0uJHqvr1qPSkXqtiXywhVTC6wt/EJJOTv+g6LucpelfC3wXgtADb6p/Wxa5Et6QU3UgpeSoMke3yk6vNEIxtPiatXDMDURmmkFdxdVh6ts9Jh5aC04lZE1A/gTUTNBKdFapxgglzqDg3cg/utNlx"
    ];
    privilegedKeys = [ "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIL9rXlWqIfjVL5fB2kVzN0SQO472HzUugvZGa7Q/MLk2 root@all" ];
    enableOpenldap = false;
    enableGnome = false;
    enableGnomeKeyring = false;
    enableOciContainers = !self.isMinimalSystem;
    # https://discourse.nixos.org/t/podman-containers-always-fail-to-start/11908
    ociContainerBackend = "docker";
    ociContainerNetwork = "bus";
    enableAllOciContainers = false;
    ociContainers = {
      enablePostgresql = self.enableAllOciContainers;
      enableRedis = self.enableAllOciContainers;
      enableKosyncsrv = self.enableAllOciContainers;
      enableCloudBeaver = self.enableAllOciContainers
        && (self.nixosSystem == "x86_64-linux");
      enableAuthelia = self.enableAllOciContainers || self.enableTraefik;
      enableAutheliaLocalUsers = true;
      enableFreeipa = false;
      enableKeeweb = self.enableAllOciContainers;
      enableHledger = self.enableAllOciContainers
        && (self.nixosSystem == "x86_64-linux");
      enableSearx = self.enableAllOciContainers;
      enableVault = self.enableAllOciContainers;
      enableRssBridge = self.enableAllOciContainers;
      enableWallabag = self.enableAllOciContainers;
      enableCodeServer = self.enableAllOciContainers && !self.enableCodeServer;
      enableRecipes = self.enableAllOciContainers;
      enableBookwyrm = self.enableAllOciContainers;
      enableSuperset = false;
      enableWger = self.enableAllOciContainers
        && (self.nixosSystem == "x86_64-linux");
      enableEtesync = self.enableAllOciContainers;
      enableEtesyncDav = self.enableAllOciContainers
        && (self.nixosSystem == "x86_64-linux");
      enableN8n = self.enableAllOciContainers;
      enableGitea = self.enableAllOciContainers;
      enableYacd = self.enableClashRedir;
      enableWikijs = false;
      enableXwiki = false;
      enableHuginn = self.enableAllOciContainers;
      enableWakapi = self.enableAllOciContainers;
      enableTiddlyWiki = self.enableAllOciContainers;
      enableUnigraph = false;
      enableGrocy = self.enableAllOciContainers;
      enableLldap = self.enableAllOciContainers;
      enableCalibreWeb = self.enableAllOciContainers;
      enableDokuwiki = self.enableAllOciContainers;
      enableTrilium = self.enableAllOciContainers;
      enableHomer = self.enableAllOciContainers || self.enableTraefik;
      enablePerkeep = self.enableAllOciContainers;
      enableVaultwarden = self.enableAllOciContainers;
      enablePleroma = self.enableAllOciContainers;
      enableLivebook = self.enableAllOciContainers;
      enableJoplin = self.enableAllOciContainers;
      enableMiniflux = self.enableAllOciContainers;
      enableAtuin = self.enableAllOciContainers;
      enableNextcloud = false;
      enableSftpgo = self.enableAllOciContainers;
      enableFilestash = self.enableAllOciContainers
        && (self.nixosSystem == "x86_64-linux");
    };
    emulatedSystems =
      if (self.nixosSystem == "x86_64-linux") then [ "aarch64-linux" "riscv64-linux" ] else [ ];
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
    } // (if self.enablePowerSavingMode then {
      # See https://wiki.archlinux.org/title/Power_management
      "kernel.nmi_watchdog" = 0;
      "vm.laptop_mode" = 5;
      "vm.dirty_writeback_centisecs" = 1500;
    } else { });
    networkingInterfaces = { };
    nixosStableVersion = "20.09";
    enableUnstableNixosChannel = false;
    nixosAutoUpgrade = {
      nixosChannelList = [ "stable" "unstable" "unstable-small" ];
      homeManagerChannel =
        "https://github.com/rycee/home-manager/archive/master.tar.gz";
      enableHomeManager = true;
      updateMyPackages = true;
      allowReboot = false;
      nixosRebuildFlags = [ ];
      onCalendar = "04:30";
    };
    extraOutputsToInstall = [ "dev" "lib" "doc" "info" "devdoc" "out" "man" ];
  };

  hostSpecific = self: super:
    {
      inherit hostname hostId;
    } // (if hostname == "default" then {
      isMinimalSystem = true;
    } else if systems ? "${hostname}" then
      let
        nixosSystem = systems."${hostname}";
        isForCiCd = builtins.match "cicd-(.*)" hostname != null;
        # Only enable essential packages.
        isMinimal = builtins.match "minimal-(.*)" hostname != null;
        # Always enable everything to build fairly large packages.
        isMaximal = builtins.match "maximal-(.*)" hostname != null;
      in
      ({
        inherit nixosSystem;
        isMinimalSystem = true;
      } // (if isForCiCd then
        {
          enableZerotierone = true;
          enableEmacs = true;
          enableAcme = true;
        } // (if nixosSystem == "x86_64-linux" then {
          enableVirtualboxHost = true;
        } else if nixosSystem == "aarch64-linux" then {
          installHomePackages =
            false; # Building aarch64 on qemu is too slow to be of any use.
        } else
          { })
      else
        { })
      // (if isMaximal then
        {
          isMaximalSystem = true;
          isMinimalSystem = false;
          enableAllOciContainers = true;
          enableTraefik = true;
          enablePrometheus = true;
          enablePromtail = true;
          enableAcme = true;
          enableSmosServer = true;
          enableVirtualboxHost = true;
          enableZerotierone = true;
          enableEmacs = true;
        }
      else
        { }))
    else if hostname == "uzq" then {
      enableHidpi = true;
      # enableAnbox = true;
      pkgsRelatedPrefs = super.pkgsRelatedPrefs // {
        consoleFont =
          "${pkgs.terminus_font}/share/consolefonts/ter-g20n.psf.gz";
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
    } else if hostname == "dbx" then {
      isMinimalSystem = true;
      isVagrantBox = true;
      pkgsRelatedPrefs = super.pkgsRelatedPrefs // {
        kernelPackages = pkgs.linuxPackages;
      };
    } else if hostname == "adx" then {
      isMinimalSystem = false;
      isVagrantBox = true;
    } else if hostname == "dvm" then {
      isMinimalSystem = true;
      enableMicrovmGuest = true;
      enableOfflineimap = false;
      enablePulseaudio = false;
      microvmGuestConfig = {
        volumes = [
          {
            mountPoint = "/var";
            image = "var.img";
            size = 10 * 1024;
          }
        ];
        shares = [{
          # use "virtiofs" for MicroVMs that are started by systemd
          proto = "9p";
          tag = "ro-store";
          # a host's /nix/store will be picked up so that the
          # size of the /dev/vda can be reduced.
          source = "/nix/store";
          mountPoint = "/nix/.ro-store";
        }];
        socket = "control.socket";
        # relevant for delarative MicroVM management
        hypervisor = "qemu";
        vcpu = 4;
        mem = 4 * 1024;
      };
    } else if hostname == "dqe" then {
      isMinimalSystem = true;
    } else if hostname == "ssg" then {
      isMinimalSystem = false;
      hostId = "b6653e48";
      systemStateVersion = "21.05";
      dpi = 128;
      enableX2goServer = true;
      enableHidpi = false;
      maxJobs = 6;
      smartctlExporterDevices = [ "/dev/nvme0n1" ];
      enableCfssl = true;
      # enableK3s = true;
      enablePrometheus = true;
      enablePromtail = true;
      enableWireless = true;
      enableAcme = true;
      pkgsRelatedPrefs = super.pkgsRelatedPrefs // (with super.pkgsRelatedPrefs;
        {
          consoleFont =
            "${pkgs.terminus_font}/share/consolefonts/ter-g20n.psf.gz";
        });
      enableTraefik = true;
      enableAllOciContainers = false;
      ociContainers = super.ociContainers // { };
    } else if hostname == "jxt" then {
      isMinimalSystem = false;
      hostId = "5ee92b8d";
      smartctlExporterDevices = [ "/dev/nvme0n1" ];
      enableNetworkWatchdog = true;
      enablePrometheus = true;
      enablePromtail = true;
      enableHolePuncher = false;
      enableAutossh = false;
      enablePrinting = false;
      enableEternalTerminal = false;
      enableZerotierone = false;
      autoStartClashRedir = false;
      dnsServers = [ "10.10.61.128" "10.10.61.129" ];
      enableTraefik = true;
      ociContainers = super.ociContainers // { };
    } else if hostname == "shl" then {
      enableXserver = false;
      enableAria2 = true;
      enableTraefik = true;
      enableAllOciContainers = false;
      installHomePackages = false; # Too slow.
      kernelParams = super.kernelParams
      ++ [ "cgroup_enable=cpuset" "cgroup_enable=memory" "cgroup_memory=1" ];
      nixosSystem = "aarch64-linux";
      isMinimalSystem = true;
      hostId = "6fce2459";
      pkgsRelatedPrefs = super.pkgsRelatedPrefs // {
        kernelPackages = pkgs.linuxPackages_rpi4;
      };
      enableAcme = true;
      enableZerotierone = true;
      enableTailScale = false;
      enableVirtualboxHost = false;
      bootloader = "raspberrypi";
      isRaspberryPi = true;
      raspberryPiVersion = 4;
      enableVsftpd = false;
    } else if hostname == "gcv" then {
      nixosSystem = "x86_64-darwin";
    } else if hostname == "mdq" then {
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
      enableAllOciContainers = true;
      enableClashRedirWatchdog = true;
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
          extraArgs = [ "--verbose" "--readonly" "--debug" ];
        };
        "tank/VAR/var" = {
          autoprune = true;
          autosnap = true;
          daily = 7;
          hourly = 24;
          monthly = 1;
          yearly = 1;
          extraArgs = [ "--verbose" "--readonly" "--debug" ];
        };
      };
      enableTraefik = true;
      enablePrometheus = true;
      enablePromtail = true;
      enableAcme = true;
      enableSmosServer = true;
      initrdKernelModules = super.initrdKernelModules ++ [ "r8169" ];
      pkgsRelatedPrefs = super.pkgsRelatedPrefs // (with super.pkgsRelatedPrefs;
        {
          extraModulePackages = extraModulePackages ++ [
            kernelPackages.rtl88x2bu
          ];
          consoleFont =
            "${pkgs.terminus_font}/share/consolefonts/ter-g20n.psf.gz";
          extraUdevRules =
            let
              name = "rfkill-wrapper";
              application = with pkgs; writeShellApplication {
                inherit name;
                text = ''
                  action="$1"
                  device_name="$2"
                  id="$(rfkill --output-all | grep -Po "([0-9]+)(?=.*$device_name)")"
                  rfkill "$action" "$id"
                '';
                runtimeInputs = [
                  utillinux
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
    } else if hostname == "aol" then {
      isMinimalSystem = false;
      hostId = "85d4bfd4";
      systemStateVersion = "22.05";
      homeManagerStateVersion = "22.05";
      enableTraefik = true;
      enablePrometheus = true;
      enablePromtail = true;
      enableAcme = true;
      enableSmosServer = true;
      ociContainers = super.ociContainers // {
        enableCalibreWeb = true;
        enableKeeweb = true;
      };
      videoDrivers = [ "nvidia" "modesetting" ];
      enableNvidiaPrimeConfig = true;
      enableNvidiaModesetting = true;
      nvidiaPrimeConfig = {
        offload = { enable = true; };
        nvidiaBusId = "PCI:1:0:0";
        intelBusId = "PCI:0:2:0";
      };
      enableAndroidDevEnv = true;
    } else if hostname == "madbox" then {
      isMinimalSystem = true;
      isHomeManagerOnly = true;
      enableHomeManagerSyncthing = true;
    } else {
      isMinimalSystem = true;
    });

  overrides = builtins.map (path: (import (builtins.toPath path)))
    (builtins.filter (x: builtins.pathExists x) prefFiles);

  unevaluated = fix
    (builtins.foldl' (acc: override: extends override acc) default
      ([ hostSpecific ] ++ overrides));
  pkgsRelatedPrefs = unevaluated.pkgsRelatedPrefs;
  notPkgsRelatedPrefs =
    let p = builtins.removeAttrs unevaluated [ "pkgsRelatedPrefs" ];
    in builtins.deepSeq p p;
  final = notPkgsRelatedPrefs // pkgsRelatedPrefs;
in
{
  pure = notPkgsRelatedPrefs;
  pkgsRelated = pkgsRelatedPrefs;
  all = final;
}
