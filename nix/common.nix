{ config, pkgs, lib, inputs, ... }@args:
let
  prefs = let
    p = import ./prefs.nix args;
    all = p.all;
  in builtins.trace "final configuration for host ${all.hostname}"
  (builtins.trace all all);
  stable = pkgs.stable;
  unstable = pkgs.unstable;
  impure = {
    mitmproxyCAFile = "${prefs.home}/.mitmproxy/mitmproxy-ca.pem";
    wpaSupplicantConfigFile =
      "${prefs.home}/.config/wpa_supplicant/wpa_supplicant.conf";
    consoleKeyMapFile = "${prefs.home}/.local/share/kbd/keymaps/personal.map";
    sslhConfigFile = "${prefs.home}/.config/sslh/sslh.conf";
    sshAuthorizedKeys = "${prefs.home}/.ssh/authorized_keys";
    sshHostKeys = [
      "${prefs.home}/.local/secrets/initrd/ssh_host_rsa_key"
      "${prefs.home}/.local/secrets/initrd/ssh_host_ed25519_key"
    ];
  };
  toYAML = name: attrs:
    pkgs.runCommandNoCC name {
      preferLocalBuild = true;
      json = builtins.toFile "${name}.json" (builtins.toJSON attrs);
      nativeBuildInputs = [ pkgs.remarshal ];
    } "json2yaml -i $json -o $out";

  getTraefikBareDomainRule =
    lib.concatMapStringsSep " || " (domain: "Host(`${domain}`)") prefs.domains;
  getTraefikRuleByDomainPrefix = let
    getRuleByPrefix = domainPrefix:
      lib.concatMapStringsSep " || " (domain: "Host(`${domain}`)")
      (prefs.getFullDomainNames domainPrefix);
  in domainPrefixes:
  lib.concatMapStringsSep " || " getRuleByPrefix
  (lib.splitString "," domainPrefixes);
in {
  imports = let
    smosConfiguration = { config, pkgs, lib, inputs, ... }: {
      imports = [
        (import (inputs.smos + "/nix/nixos-module.nix") {
          envname = "production";
        })
      ];

      config = {
        nix.binaryCaches = [ "https://smos.cachix.org" ];
        nix.binaryCachePublicKeys =
          [ "smos.cachix.org-1:YOs/tLEliRoyhx7PnNw36cw2Zvbw5R0ASZaUlpUv+yM=" ];

        services.smos = {
          production = {
            enable = true;
            web-server = {
              enable = true;
              log-level = "Info";
              hosts = prefs.getFullDomainNames "smos";
              port = 8403;
              api-url = "https://${
                  builtins.head config.services.smos.production.api-server.hosts
                }";
              web-url = "https://${prefs.getFullDomainName "smos"}";
              # TODO: error: The option `services.smos.production.web-server.data-dir' does not exist.
              # data-dir = "${prefs.syncFolder}/workflow";
            };
            api-server = {
              enable = true;
              log-level = "Info";
              hosts = prefs.getFullDomainNames "smos-api";
              port = 8402;
              local-backup = { enable = true; };
            };
          };
        };
      };
    };
  in (builtins.filter (x: builtins.pathExists x) [ ./machine.nix ./cachix.nix ])
  ++ (lib.optionals prefs.enableSmosServer [ smosConfiguration ]);
  security = {
    sudo = { wheelNeedsPassword = false; };
    acme = {
      acceptTerms = true;
      email = prefs.acmeEmail;
      certs = prefs.acmeCerts;
    };
    pki = {
      caCertificateBlacklist = [
        "WoSign"
        "WoSign China"
        "CA WoSign ECC Root"
        "Certification Authority of WoSign G2"
      ];
      certificateFiles = let
        mitmCA = pkgs.lib.optionals (builtins.pathExists impure.mitmproxyCAFile)
          [
            (builtins.toFile "mitmproxy-ca.pem"
              (builtins.readFile impure.mitmproxyCAFile))
          ];
        CAs = [ ];
      in mitmCA ++ CAs;
    };
    pam = {
      enableSSHAgentAuth = true;
      mount = {
        enable = true;
        extraVolumes = [
          ''<luserconf name=".pam_mount.conf.xml" />''
          ''
            <fusemount>${pkgs.fuse}/bin/mount.fuse %(VOLUME) %(MNTPT) "%(before=\"-o \" OPTIONS)"</fusemount>''
          "<fuseumount>${pkgs.fuse}/bin/fusermount -u %(MNTPT)</fuseumount>"
          "<path>${pkgs.fuse}/bin:${pkgs.coreutils}/bin:${pkgs.utillinux}/bin:${pkgs.gocryptfs}/bin</path>"
        ];
      };
      services."${prefs.owner}" = {
        fprintAuth = prefs.enableFprintAuth;
        limits = [
          {
            domain = "*";
            type = "hard";
            item = "nofile";
            value = "51200";
          }
          {
            domain = "*";
            type = "soft";
            item = "nofile";
            value = "51200";
          }
        ];
        enableGnomeKeyring = prefs.enableGnomeKeyring;
        pamMount = true;
        sshAgentAuth = true;
        setEnvironment = true;
      };
    };
  };

  networking = {
    hostName = prefs.hostname;
    hostId = prefs.hostId;
    wireless = {
      enable = prefs.enableSupplicant;
      # userControlled = { enable = true; };
      iwd.enable = prefs.enableIwd;
    };
    supplicant = pkgs.lib.optionalAttrs prefs.enableSupplicant {
      "WLAN" = {
        configFile = let
          defaultPath = "/etc/wpa_supplicant.conf";
          path = if builtins.pathExists impure.wpaSupplicantConfigFile then
            impure.wpaSupplicantConfigFile
          else
            defaultPath;
        in {
          # TODO: figure out why this does not work.
          inherit (path)
          ;
          writable = true;
        };
      };
    };
    proxy.default = prefs.proxy;
    enableIPv6 = prefs.enableIPv6;
  };

  console = {
    keyMap = let p = impure.consoleKeyMapFile;
    in if builtins.pathExists p then
      (builtins.toFile "personal-keymap" (builtins.readFile p))
    else
      "us";
    font = if prefs.consoleFont != null then
      prefs.consoleFont
    else if prefs.enableHidpi then
      "${pkgs.terminus_font}/share/consolefonts/ter-g28n.psf.gz"
    else
      "${pkgs.terminus_font}/share/consolefonts/ter-g16n.psf.gz";
  };

  i18n = {
    defaultLocale = "de_DE.UTF-8";
    supportedLocales = [
      "en_US.UTF-8/UTF-8"
      "de_DE.UTF-8/UTF-8"
      "fr_FR.UTF-8/UTF-8"
      "zh_CN.UTF-8/UTF-8"
    ];
    inputMethod = {
      enabled = prefs.enabledInputMethod;
      ibus.engines = with pkgs.ibus-engines; [
        libpinyin
        table
        table-chinese
        table-others
      ];
      fcitx.engines = with pkgs.fcitx-engines; [
        libpinyin
        cloudpinyin
        rime
        table-extra
        table-other
      ];
    };
  };

  time = {
    timeZone = "Asia/Shanghai";
    hardwareClockInLocalTime = true;
  };

  environment = {
    etc = {
      "davfs2/secrets" = {
        enable = prefs.enableDavfs2 && builtins.pathExists prefs.davfs2Secrets;
        mode = "0600";
        source = prefs.davfs2Secrets;
      };
      hosts.mode = "0644";
    } // lib.optionalAttrs (prefs.enableCrio && prefs.enableZfs) {
      "crio/crio.conf.d/01-zfs.conf".text = ''
        [crio]
        storage_driver = "zfs"
      '';
    } // lib.optionalAttrs prefs.enableResolved {
      "systemd/resolved.conf" = { mode = "0644"; };
    };

    extraOutputsToInstall = prefs.extraOutputsToInstall;
    systemPackages = with pkgs;
      builtins.filter (x: x != null) [
        manpages
        fuse
        bindfs
        iptables
        iproute
        ethtool
        nftables
        ipset
        dnsmasq
        (args.inputs.deploy-rs.defaultPackage.${config.nixpkgs.system} or null)
        nixFlakes
        nix-info
        nixos-generators
        niv
        nix-serve
        home-manager
        nixpkgs-fmt
        nixfmt
        nix-du
        nix-index
        nix-top
        # gnome.adwaita-icon-theme
        # gnome.dconf
        # gnome.gsettings-desktop-schemas
        # gnome.zenity
        # font-manager
        udiskie
        fzf
        jq
        virt-manager
        fdm
        mailutils
        notify-osd-customizable
        noti
        libnotify
        (pkgs.myPackages.lua or lua)
        nodejs_latest
        gcc
        gnumake
        podman
        trash-cli
        podman-compose
        usbutils
        powertop
        fail2ban
        ldns
        bind
        tree
        nix-prefetch-scripts
        pulsemixer
        acpilight
        xorg.xev
        xorg.libX11
        xorg.libXft
        xorg.libXpm
        xorg.libXinerama
        xorg.libXext
        xorg.libXrandr
        xorg.libXrender
        xorg.xorgproto
        libxkbcommon
        pixman
        wlroots
        libevdev
        wayland
        wayland-protocols
        python3
        # (pkgs.myPackages.pythonStable or python3)
        # (pkgs.myPackages.python2 or python2)
        nvimpager
        (pkgs.myPackages.nvimdiff or null)
        (pkgs.myPackages.aioproxy or null)
        rofi
        ruby
        perl
        emacs
        neovim
        vim
        libffi
        pciutils
        utillinux
        ntfs3g
        gparted
        gnupg
        pinentry
        atool
        atop
        bash
        zsh
        ranger
        gptfdisk
        curl
        at
        git
        chezmoi
        coreutils
        file
        sudo
        gettext
        sxhkd
        mimeo
        libsecret
        gnome.seahorse
        mlocate
        htop
        iotop
        iftop
        iw
        alacritty
        rxvt-unicode
        lsof
        age
        sops
        dmenu
        dmidecode
        dunst
        cachix
        e2fsprogs
        efibootmgr
        dbus
        cryptsetup
        compton
        blueman
        bluez
        bluez-tools
        exfat
        i3blocks
        i3lock
        i3status
        firefox
        rsync
        rclone
        restic
        sshfs
        termite
        xbindkeys
        xcape
        xautolock
        xdotool
        xlibs.xmodmap
        xmacro
        autokey
        xsel
        xvkbd
        fcron
        gmp
        libcap
      ] ++ (if (prefs.enableTailScale) then [ tailscale ] else [ ])
      ++ (if (prefs.enableCodeServer) then [ code-server ] else [ ])
      ++ (if (prefs.enableZfs) then [ zfsbackup ] else [ ])
      ++ (if (prefs.enableBtrfs) then [ btrbk btrfs-progs ] else [ ])
      ++ (if (prefs.enableClashRedir) then [ clash ] else [ ])
      ++ (if (prefs.enableK3s) then [ k3s ] else [ ])
      ++ (if prefs.enableDocker then [ docker-buildx ] else [ ])
      ++ (if prefs.enableWstunnel then [ wstunnel ] else [ ])
      ++ (if prefs.enableXmonad then [ xmobar ] else [ ])
      ++ (if (prefs.nixosSystem == "x86_64-linux") then [
        hardinfo
        # steam-run-native
        # aqemu
        wine
        bpftool
        prefs.kernelPackages.perf
        # TODO: broken for now, see https://github.com/NixOS/nixpkgs/issues/140358
        # prefs.kernelPackages.bpftrace
        prefs.kernelPackages.bcc
      ] else
        [ ]) ++ (if prefs.enableActivityWatch then
          with inputs.jtojnar-nixfiles.packages.${prefs.nixosSystem}; [
            aw-server-rust
            aw-watcher-afk
            aw-watcher-window
          ]
        else
          [ ]);
    enableDebugInfo = prefs.enableDebugInfo;
    shellAliases = {
      ssh = "ssh -C";
      bc = "bc -l";
    };
    sessionVariables = pkgs.lib.optionalAttrs (prefs.enableSessionVariables)
      (rec {
        MYSHELL = if prefs.enableZSH then "zsh" else "bash";
        MYTERMINAL = if prefs.enableUrxvtd then "urxvtc" else "alacritty";
        GOPATH = "$HOME/.go";
        CABALPATH = "$HOME/.cabal";
        CARGOPATH = "$HOME/.cargo";
        NODE_PATH = "$HOME/.node";
        PERLBREW_ROOT = "$HOME/.perlbrew-root";
        LOCALBINPATH = "$HOME/.local/bin";
        # help building locally compiled programs
        LIBRARY_PATH = "$HOME/.nix-profile/lib:/run/current-system/sw/lib";
        # Don't set LD_LIBRARY_PATH here, there will be various problems.
        MY_LD_LIBRARY_PATH =
          "$HOME/.nix-profile/lib:/run/current-system/sw/lib";
        # cmake does not respect LIBRARY_PATH
        CMAKE_LIBRARY_PATH =
          "$HOME/.nix-profile/lib:/run/current-system/sw/lib";
        # Linking can sometimes fails because ld is unable to find libraries like libstdc++.
        # export LIBRARY_PATH="$LIBRARY_PATH:$CC_LIBRARY_PATH"
        CC_LIBRARY_PATH = "/local/lib";
        # header files
        CPATH = "$HOME/.nix-profile/include:/run/current-system/sw/include";
        C_INCLUDE_PATH =
          "$HOME/.nix-profile/include:/run/current-system/sw/include";
        CPLUS_INCLUDE_PATH =
          "$HOME/.nix-profile/include:/run/current-system/sw/include";
        CMAKE_INCLUDE_PATH =
          "$HOME/.nix-profile/include:/run/current-system/sw/include";
        # pkg-config
        PKG_CONFIG_PATH =
          "$HOME/.nix-profile/lib/pkgconfig:$HOME/.nix-profile/share/pkgconfig:/run/current-system/sw/lib/pkgconfig:/run/current-system/sw/share/pkgconfig";
        PATH = [ "$HOME/.bin" "$HOME/.local/bin" ]
          ++ (map (x: x + "/bin") [ CABALPATH CARGOPATH GOPATH ])
          ++ [ "${NODE_PATH}/node_modules/.bin" ] ++ [ "/usr/local/bin" ];
        LESS = "-F -X -R";
        EDITOR = "nvim";
      } // pkgs.lib.optionalAttrs (pkgs ? myPackages) {
        # export PYTHONPATH="$MYPYTHONPATH:$PYTHONPATH"
        MYPYTHONPATH =
          (pkgs.myPackages.pythonPackages.makePythonPath or pkgs.python3Packages.makePythonPath)
          [ (pkgs.myPackages.python or pkgs.python) ];
        PAGER = "nvimpager";
      });
    variables = {
      # systemctl --user does not work without this
      # https://serverfault.com/questions/887283/systemctl-user-process-org-freedesktop-systemd1-exited-with-status-1/887298#887298
      # XDG_RUNTIME_DIR = ''/run/user/"$(id -u)"'';
    };
  };

  programs = {
    ccache = { enable = prefs.enableCcache; };
    java = { enable = prefs.enableJava; };
    gnupg.agent = { enable = prefs.enableGPGAgent; };
    ssh = { startAgent = true; };
    # vim.defaultEditor = true;
    adb.enable = prefs.enableADB;
    slock.enable = prefs.enableSlock;
    bash = { enableCompletion = true; };
    zsh = {
      enable = prefs.enableZSH;
      enableCompletion = true;
      ohMyZsh = { enable = true; };
      shellInit = "zsh-newuser-install() { :; }";
    };
    # light.enable = true;
    sway = {
      enable = true;
      extraPackages = with pkgs; [ swaylock swayidle alacritty dmenu ];
    };
    tmux = { enable = true; };
    wireshark.enable = prefs.enableWireshark;
  };

  fonts = {
    enableDefaultFonts = true;
    # fontDir.enable = true;
    fontconfig = { enable = true; };
    fonts = with pkgs; [
      wqy_microhei
      wqy_zenhei
      source-han-sans-simplified-chinese
      source-han-serif-simplified-chinese
      arphic-ukai
      arphic-uming
      noto-fonts-cjk
      inconsolata
      ubuntu_font_family
      hasklig
      fira-code
      fira-code-symbols
      cascadia-code
      jetbrains-mono
      corefonts
      source-code-pro
      source-sans-pro
      source-serif-pro
      noto-fonts-emoji
      lato
      line-awesome
      material-icons
      material-design-icons
      font-awesome
      font-awesome_4
      fantasque-sans-mono
      dejavu_fonts
      terminus_font
    ];
  };

  # Open ports in the firewall.
  # networking.firewall.allowedTCPPorts = [ ... ];
  # networking.firewall.allowedUDPPorts = [ ... ];
  # Or disable the firewall altogether.
  networking.firewall.enable = prefs.enableFirewall;

  sound = {
    enable = true;
    mediaKeys = { enable = prefs.enableMediaKeys; };
  };

  nixpkgs = let
    cross = if prefs.enableAarch64Cross then rec {
      crossSystem = (import <nixpkgs>
        { }).pkgsCross.aarch64-multiplatform.stdenv.targetPlatform;
      localSystem = crossSystem;
    } else
      { };
    configAttr = {
      config = {
        allowUnfree = true;
        allowBroken = true;
        pulseaudio = true;
        experimental-features = "nix-command flakes";
      };
    };
  in configAttr // cross;

  hardware = {
    enableAllFirmware = true;
    enableRedistributableFirmware = true;
    opengl = {
      enable = true;
      driSupport = true;
    };
    bumblebee = {
      enable = prefs.enableBumblebee;
      connectDisplay = true;
    };
    pulseaudio = {
      enable = !prefs.enablePipewire;
      package = pkgs.pulseaudioFull;
      support32Bit = true;
      systemWide = true;
      extraModules = [ pkgs.pulseaudio-modules-bt ];
    };
    bluetooth = {
      enable = prefs.enableBluetooth;
      package = pkgs.bluezFull;
      powerOnBoot = prefs.enableBluetooth;
    };
    acpilight = { enable = prefs.enableAcpilight; };
  };

  location = {
    latitude = 39.55;
    longitude = 116.23;
  };

  system = {
    activationScripts = let
      jdks = builtins.filter (x: pkgs ? x) prefs.linkedJdks;
      addjdk = jdk:
        if pkgs ? jdk then
          let p = pkgs.${jdk}.home; in "ln -sfn ${p} /local/jdks/${jdk}"
        else
          "";
    in pkgs.lib.optionalAttrs (prefs.enableJava && jdks != [ ]) {
      jdks = {
        text = pkgs.lib.concatMapStringsSep "\n" addjdk jdks;
        deps = [ "local" ];
      };
    } // {
      mkCcacheDirs = {
        text = "install -d -m 0777 -o root -g nixbld /var/cache/ccache";
        deps = [ ];
      };
      usrlocalbin = {
        text = "mkdir -m 0755 -p /usr/local/bin";
        deps = [ ];
      };
      local = {
        text =
          "mkdir -m 0755 -p /local/bin && mkdir -m 0755 -p /local/lib && mkdir -m 0755 -p /local/jdks";
        deps = [ ];
      };
      cclibs = {
        text =
          "cd /local/lib; for i in ${pkgs.gcc.cc.lib}/lib/*; do ln -sfn $i; done";
        deps = [ "local" ];
      };

      # Fuck /bin/bash
      binbash = {
        text = "ln -sfn ${pkgs.bash}/bin/bash /bin/bash";
        deps = [ "binsh" ];
      };

      # sftpman
      mntsshfs = {
        text =
          "install -d -m 0700 -o ${prefs.owner} -g ${prefs.ownerGroup} /mnt/sshfs";
        deps = [ ];
      };

      # rclone
      mntrclone = {
        text =
          "install -d -m 0700 -o ${prefs.owner} -g ${prefs.ownerGroup} /mnt/rclone";
        deps = [ ];
      };

      # https://github.com/NixOS/nixpkgs/issues/3702
      linger = {
        text = ''
          # remove all existing lingering users
          rm -r /var/lib/systemd/linger
          mkdir /var/lib/systemd/linger
          # enable for the subset of declared users
          touch /var/lib/systemd/linger/${prefs.owner}
        '';
        deps = [ ];
      };

      # Fuck pre-built dynamic binaries
      # copied from https://github.com/NixOS/nixpkgs/pull/69057
      ldlinux = {
        text = with pkgs.lib;
          concatStrings (mapAttrsToList (target: source: ''
            mkdir -m 0755 -p $(dirname ${target})
            ln -sfn ${escapeShellArg source} ${target}.tmp
            mv -f ${target}.tmp ${target} # atomically replace
          '') {
            "i686-linux"."/lib/ld-linux.so.2" =
              "${pkgs.glibc.out}/lib/ld-linux.so.2";
            "x86_64-linux"."/lib/ld-linux.so.2" =
              "${pkgs.pkgsi686Linux.glibc.out}/lib/ld-linux.so.2";
            "x86_64-linux"."/lib64/ld-linux-x86-64.so.2" =
              "${pkgs.glibc.out}/lib64/ld-linux-x86-64.so.2";
            "aarch64-linux"."/lib/ld-linux-aarch64.so.1" =
              "${pkgs.glibc.out}/lib/ld-linux-aarch64.so.1";
            "armv7l-linux"."/lib/ld-linux-armhf.so.3" =
              "${pkgs.glibc.out}/lib/ld-linux-armhf.so.3";
          }.${pkgs.stdenv.system} or { });
        deps = [ ];
      };

      # make some symlinks to /bin, just for convenience
      binShortcuts = {
        text = ''
          ln -sfn ${pkgs.neovim}/bin/nvim /usr/local/bin/nv
        '';
        deps = [ "binsh" "usrlocalbin" ];
      };
    };
  };

  services = {
    udev = {
      extraRules = ''
        SUBSYSTEM=="power_supply", ATTR{status}=="Discharging", ATTR{capacity}=="[0-5]", RUN+="${pkgs.systemd}/bin/systemctl poweroff"
      '';
    };
    arbtt = { enable = prefs.enableArbtt; };
    compton = { enable = prefs.enableCompton; };
    connman = { enable = prefs.enableConnman; };
    aria2 = {
      enable = prefs.enableAria2;
      extraArguments = "--rpc-listen-all --rpc-secret $ARIA2_RPC_SECRET";
    };
    openldap = let
      mkCommon = baseDN: ''
        dn: ou=People,${baseDN}
        ou: People
        objectClass: top
        objectClass: organizationalUnit

        dn: ou=Group,${baseDN}
        ou: Group
        objectClass: top
        objectClass: organizationalUnit

        dn: cn=Manager,${baseDN}
        cn: Manager
        objectClass: top
        objectclass: organizationalRole
        roleOccupant: ${baseDN}

        dn: uid=testuser,${baseDN}
        objectClass: account
        uid: testuser

        dn: uid=johndoe,ou=People,${baseDN}
        objectClass: top
        objectClass: person
        objectClass: organizationalPerson
        objectClass: inetOrgPerson
        cn: John Doe
        sn: Doe
        userPassword: xxxxxxxxxx
      '';
      mkDomain = domain: tld: ''
        dn: dc=${domain},dc=${tld}
        objectClass: domain
        dc: ${domain}
      '';
      mkOrg = org: ''
        dn: o=${org}
        objectClass: organization
      '';
    in {
      enable = prefs.enableOpenldap;
      settings = {
        children = {
          "cn=schema".includes = [
            "${pkgs.openldap}/etc/schema/core.ldif"
            "${pkgs.openldap}/etc/schema/cosine.ldif"
            "${pkgs.openldap}/etc/schema/inetorgperson.ldif"
            "${pkgs.openldap}/etc/schema/nis.ldif"
          ];
          "olcDatabase={1}mdb" = {
            attrs = {
              objectClass = [ "olcDatabaseConfig" "olcMdbConfig" ];
              olcDatabase = "{1}mdb";
              olcDbDirectory = "/var/db/openldap/localhost";
              olcSuffix = "o=localhost";
              olcRootDN = "cn=root,o=localhost";
              olcRootPW = { path = "/run/secrets/openldap-root-password"; };
              olcAccess = [
                ''
                  to attrs=userPassword,givenName,sn,photo by self write by anonymous auth by dn.base="cn=Manager,o=localhost" write by * none''
              ] ++ [
                ''
                  to * by self read by dn.base="cn=Manager,o=localhost" write by * none''
              ];
            };
          };
          "olcDatabase={2}mdb" = {
            attrs = {
              objectClass = [ "olcDatabaseConfig" "olcMdbConfig" ];
              olcDatabase = "{2}mdb";
              olcDbDirectory = "/var/db/openldap/cont.run";
              olcSuffix = "dc=cont,dc=run";
              olcRootDN = "cn=root,dc=cont,dc=run";
              olcRootPW = { path = "/run/secrets/openldap-root-password"; };
            };
          };
        };
      };
      declarativeContents."dc=cont,dc=run" = builtins.concatStringsSep "\n" [
        (mkDomain "cont" "run")
        (mkCommon "dc=cont,dc=run")
      ];

      declarativeContents."o=localhost" = builtins.concatStringsSep "\n" [
        (mkOrg "localhost")
        (mkCommon "o=localhost")
      ];
    };
    # calibre-server = {
    #   enable = prefs.enableCalibreServer;
    #   libraries = calibreServerLibraries;
    # };
    vsftpd = {
      enable = prefs.enableVsftpd;
      userlist = [ prefs.owner ];
      userlistEnable = true;
    };
    fcron = {
      enable = prefs.enableFcron;
      maxSerialJobs = 5;
      systab = "";
    };
    offlineimap = {
      enable = prefs.enableOfflineimap;
      install = true;
      path = [ pkgs.libsecret pkgs.dbus ];
    };
    pipewire = {
      enable = prefs.enablePipewire;
      pulse = { enable = true; };
    };
    restic = {
      backups = let
        restic-exclude-files = pkgs.writeTextFile {
          name = "restic-excluded-files";
          text = ''
            ltximg
            .stversions
            .stfolder
            .sync
            .syncthing.*.tmp
            ~syncthing~*.tmp
          '';
        };
        go = name: conf: backend: {
          "${name}-${backend}" = {
            initialize = true;
            passwordFile = "/run/secrets/restic-password";
            repository = "rclone:${backend}:restic";
            rcloneConfigFile = "/run/secrets/rclone-config";
            timerConfig = {
              OnCalendar = "00:05";
              RandomizedDelaySec = 3600 * 6;
            };
            pruneOpts = [
              "--keep-daily 7 --keep-weekly 5 --keep-monthly 12 --keep-yearly 75"
            ];
          } // conf;
        };
        mkBackup = name: conf:
          go name conf "backup-primary" // go name conf "backup-secondary";
      in mkBackup "vardata" {
        extraBackupArgs = [
          "-v=3"
          "--exclude=/postgresql"
          "--exclude=/vault/logs"
          "--exclude=/nextcloud-data"
          "--exclude=/sftpgo/data"
          "--exclude=/sftpgo/backups"
          "--exclude-file=${restic-exclude-files}"
        ];
        paths = [ "/var/data" ];
      } // mkBackup "sync" {
        extraBackupArgs = [
          "-v=3"
          "--exclude-larger-than=500M"
          "--exclude=.git"
          "--exclude-file=${restic-exclude-files}"
        ];
        paths = [ "${prefs.syncFolder}" ];
      };
    };
    glusterfs = {
      enable = prefs.enableGlusterfs;
      tlsSettings = {
        caCert = "/run/secrets/cfssl-ca-pem";
        tlsKeyPath = "/run/secrets/glusterfs-cert-key";
        tlsPem = "/run/secrets/glusterfs-cert";
      };
    };
    davfs2 = { enable = prefs.enableDavfs2; };
    coredns = {
      enable = prefs.enableCoredns;
      package = args.inputs.self.packages.${config.nixpkgs.system}.coredns;
      config = let
        dnsServers = builtins.concatStringsSep " " prefs.dnsServers;
        rewriteAliases = builtins.concatStringsSep "\n" (lib.mapAttrsToList
          (alias: host:
            "rewrite name regex (.*).${alias}.${prefs.mainDomain} ${host}.${prefs.mainDomain} answer auto")
          prefs.hostAliases);
      in ''
        ${prefs.mainDomain}:${builtins.toString prefs.corednsPort} {
            log
            debug
            # regex ${prefs.mainDomain} is not literally the string ${prefs.mainDomain},
            # it's OK, as this lies in the stanza for domain ${prefs.mainDomain}.
            ${rewriteAliases}
            # Catch-all rule, lest I must rebuild all hosts on new machines.
            rewrite name regex (.*)\.(.*)\.${prefs.mainDomain} {2}.${prefs.mainDomain} answer auto
            # fail fast on cache miss
            cancel 0.01s
            epicmdns ${prefs.mainDomain} {
              force_unicast true
              min_ttl 180
              browse_period 40
              cache_purge_period 300
              browse _workstation._tcp.local
              browse _ssh._tcp.local
            }
            # mdns ${prefs.mainDomain}
            alternate original NXDOMAIN,SERVFAIL,REFUSED . ${dnsServers}
        }

        .:${builtins.toString prefs.corednsPort} {
            log
            debug
            forward . ${dnsServers}
        }
              '';
    };
    dnsmasq = {
      enable = prefs.enableDnsmasq;
      resolveLocalQueries = prefs.dnsmasqResolveLocalQueries;
      servers = prefs.dnsmasqServers;
      extraConfig = prefs.dnsmasqExtraConfig;
    };
    smartdns = {
      enable = prefs.enableSmartdns;
      settings = prefs.smartdnsSettings;
    };
    urxvtd = { enable = prefs.enableUrxvtd; };
    resolved = {
      enable = prefs.enableResolved;
      extraConfig = builtins.concatStringsSep "\n" [
        (if prefs.enableCorednsForResolved then ''
          DNS=127.0.0.1:${builtins.toString prefs.corednsPort}
        '' else ''
          # DNS=127.0.0.1:${builtins.toString prefs.corednsPort}
          DNS=${builtins.concatStringsSep " " prefs.dnsServers}
        '')
      ];
    };
    x2goserver = { enable = prefs.enableX2goServer; };
    openssh = {
      enable = true;
      useDns = true;
      allowSFTP = true;
      forwardX11 = true;
      gatewayPorts = "yes";
      permitRootLogin = "yes";
      startWhenNeeded = true;
      extraConfig = "Include /etc/ssh/sshd_config_*";
    };
    ttyd = {
      enable = prefs.enableTtyd;
      clientOptions = { fontSize = "16"; };
    };
    samba = {
      enable = prefs.enableSamba;
      extraConfig = ''
        workgroup = WORKGROUP
        security = user
      '';
      shares = {
        owner = {
          comment = "home folder";
          path = prefs.home;
          public = "no";
          writable = "yes";
          printable = "no";
          "create mask" = "0644";
          "force user" = prefs.owner;
          "force group" = "users";
        };
        data = {
          comment = "data folder";
          path = "/data";
          public = "no";
          writable = "yes";
          printable = "no";
          "create mask" = "0644";
          "force user" = prefs.owner;
          "force group" = "users";
        };
      };
    };
    privoxy = {
      enable = prefs.enablePrivoxy;
      settings = { listen-address = "0.0.0.0:8118"; };
    };
    redshift = { enable = prefs.enableRedshift; };
    avahi = {
      browseDomains = [ prefs.mainDomain ];
      enable = prefs.enableAvahi;
      nssmdns = true;
      publish = {
        enable = true;
        userServices = true;
        addresses = true;
        domain = true;
        hinfo = true;
        workstation = true;
      };
      extraServiceFiles = (builtins.foldl' (a: t:
        a // {
          "${t}" = ''
            <?xml version="1.0" standalone='no'?><!--*-nxml-*-->
            <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
            <service-group>
              <name replace-wildcards="yes">${t} server at %h</name>
              <service>
                <type>_${t}._tcp</type>
                <port>22</port>
              </service>
            </service-group>
          '';
        }) { } [ "ssh" "sftp-ssh" ]) // {
          smb = ''
            <?xml version="1.0" standalone='no'?><!--*-nxml-*-->
            <!DOCTYPE service-group SYSTEM "avahi-service.dtd">
            <service-group>
              <name replace-wildcards="yes">samba server at %h</name>
              <service>
                <type>_smb._tcp</type>
                <port>445</port>
              </service>
            </service-group>
          '';
        };

    };
    nfs.server = {
      enable = prefs.enableNfs;
      extraNfsdConfig = ''
        udp=y
      '';
    };
    zfs = {
      autoScrub.enable = prefs.enableZfs;

      autoSnapshot = {
        enable = prefs.enableZfs;
        frequent = 8;
        hourly = 24;
        daily = 0;
        weekly = 0;
        monthly = 0;
      };
    };

    grafana = {
      enable = prefs.enableGrafana;
      rootUrl = "https://${prefs.getFullDomainName "grafana"}";
      port = prefs.grafanaPort;
      addr = "127.0.0.1";
      provision = {
        enable = true;
        datasources = [{
          access = "proxy";
          url = "\${PROMETHEUS_URL}";
          basicAuth = true;
          basicAuthUser = "\${PROMETHEUS_USERNAME}";
          basicAuthPassword = "\${PROMETHEUS_PASSWORD}";
          jsonData = { httpMethod = "POST"; };
          name = "Prometheus Remote";
          type = "prometheus";
        }] ++ [{
          access = "proxy";
          url = "\${LOKI_URL}";
          basicAuth = true;
          basicAuthUser = "\${LOKI_USERNAME}";
          basicAuthPassword = "\${LOKI_PASSWORD}";
          jsonData = { };
          name = "Loki Remote";
          type = "loki";
        }] ++ lib.optionals prefs.enablePrometheus [{
          access = "proxy";
          isDefault = true;
          jsonData = { httpMethod = "POST"; };
          name = "Prometheus";
          type = "prometheus";
          url = "http://127.0.0.1:${builtins.toString prefs.prometheusPort}";
        }] ++ lib.optionals prefs.enableLoki [{
          access = "proxy";
          jsonData = { };
          name = "Loki";
          type = "loki";
          url = "http://127.0.0.1:${builtins.toString prefs.lokiHttpPort}";
        }];
      };
    };

    prometheus = {
      enable = prefs.enablePrometheus;
      port = prefs.prometheusPort;
      environmentFile = "/run/secrets/prometheus-env";
      exporters = {
        node = { enable = true; };
        domain = { enable = true; };
        blackbox = {
          enable = true;
          configFile = toYAML "blackbox-config" {
            modules = {
              dns_test = {
                dns = {
                  ip_protocol_fallback = false;
                  preferred_ip_protocol = "ip4";
                  query_name = "example.com";
                  validate_answer_rrs = {
                    fail_if_matches_regexp = [ "test" ];
                  };
                };
                prober = "dns";
                timeout = "5s";
              };
              http_2xx = {
                http = null;
                prober = "http";
                timeout = "5s";
              };
              http_header_match_origin = {
                http = {
                  fail_if_header_not_matches = [{
                    allow_missing = false;
                    header = "Access-Control-Allow-Origin";
                    regexp = "(\\*|example\\.com)";
                  }];
                  headers = { Origin = "example.com"; };
                  method = "GET";
                };
                prober = "http";
                timeout = "5s";
              };
              http_post_2xx = {
                http = {
                  basic_auth = {
                    password = "mysecret";
                    username = "username";
                  };
                  method = "POST";
                };
                prober = "http";
                timeout = "5s";
              };
              icmp_test = {
                icmp = { preferred_ip_protocol = "ip4"; };
                prober = "icmp";
                timeout = "5s";
              };
              irc_banner = {
                prober = "tcp";
                tcp = {
                  query_response = [
                    { send = "NICK prober"; }
                    { send = "USER prober prober prober :prober"; }
                    {
                      expect = "PING :([^ ]+)";
                      send = "PONG \${1}";
                    }
                    { expect = "^:[^ ]+ 001"; }
                  ];
                };
                timeout = "5s";
              };
              pop3s_banner = {
                prober = "tcp";
                tcp = {
                  query_response = [{ expect = "^+OK"; }];
                  tls = true;
                  tls_config = { insecure_skip_verify = false; };
                };
              };
              smtp_starttls = {
                prober = "tcp";
                tcp = {
                  query_response = [
                    { expect = "^220 "; }
                    { send = "EHLO prober\r"; }
                    { expect = "^250-STARTTLS"; }
                    { send = "STARTTLS\r"; }
                    { expect = "^220"; }
                    { starttls = true; }
                    { send = "EHLO prober\r"; }
                    { expect = "^250-AUTH"; }
                    { send = "QUIT\r"; }
                  ];
                };
                timeout = "5s";
              };
              ssh_banner = {
                prober = "tcp";
                tcp = { query_response = [{ expect = "^SSH-2.0-"; }]; };
                timeout = "5s";
              };
              tcp_connect = {
                prober = "tcp";
                timeout = "5s";
              };
            };
          };
        };
        postgres = {
          enable = prefs.ociContainers.enablePostgresql;
          environmentFile = "/run/secrets/prometheus-postgres-env";
        };
      };
      remoteWrite = [{
        url = "\${REMOTE_WRITE_URL}";
        basic_auth = {
          password = "\${REMOTE_WRITE_PASSWORD}";
          username = "\${REMOTE_WRITE_USERNAME}";
        };
      }];
      scrapeConfigs = lib.optionals prefs.enableTraefik [{
        job_name = "traefik";
        static_configs = [{
          targets =
            [ "127.0.0.1:${builtins.toString prefs.traefikMetricsPort}" ];
          labels = { instance_node = prefs.hostname; };
        }];
      }] ++ lib.optionals config.services.prometheus.exporters.node.enable [{
        job_name = "node";
        static_configs = [{
          targets = [
            "127.0.0.1:${
              toString config.services.prometheus.exporters.node.port
            }"
          ];
          labels = { instance_node = prefs.hostname; };
        }];
      }]
        ++ lib.optionals config.services.prometheus.exporters.blackbox.enable [{
          job_name = "blackbox";
          metrics_path = "/probe";
          params = { module = [ "http_2xx" ]; };
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              source_labels = [ "__param_target" ];
              target_label = "instance";
            }
            {
              replacement = "127.0.0.1:${
                  builtins.toString
                  config.services.prometheus.exporters.domain.port
                }";
              target_label = "__address__";
            }
          ];
          static_configs = [{
            targets = [
              "https://www.google.com"
              "https://www.baidu.com"
              "http://neverssl.com"
            ] ++ lib.optionals prefs.enableTraefik
              (builtins.map (x: "https://${x}")
                (prefs.getFullDomainNames "traefik"));
          }];
        }]
        ++ lib.optionals config.services.prometheus.exporters.postgres.enable [{
          job_name = "domain";
          metrics_path = "/probe";
          relabel_configs = [
            {
              source_labels = [ "__address__" ];
              target_label = "__param_target";
            }
            {
              replacement = "127.0.0.1:${
                  builtins.toString
                  config.services.prometheus.exporters.domain.port
                }";
              target_label = "__address__";
            }
          ];
          static_configs = [{ targets = [ prefs.mainDomain ]; }];
        }]
        ++ lib.optionals config.services.prometheus.exporters.postgres.enable [{
          job_name = "postgres";
          static_configs = [{
            targets = [
              "127.0.0.1:${
                builtins.toString
                config.services.prometheus.exporters.postgres.port
              }"
            ];
            labels = { instance_node = prefs.hostname; };
          }];
        }];
    };

    promtail = {
      enable = prefs.enablePromtail;
      extraFlags = [ "-config.expand-env=true" ];
      configuration = {
        server = {
          http_listen_port = prefs.promtailHttpPort;
          grpc_listen_port = prefs.promtailGrpcPort;
        };
        clients = [{ url = "\${LOKI_URL}"; }]
          ++ (lib.optionals prefs.enableLoki [{
            url = "http://127.0.0.1:${
                builtins.toString prefs.lokiHttpPort
              }/loki/api/v1/push";
          }]);
        positions = { "filename" = "/var/cache/promtail/positions.yaml"; };
        scrape_configs = [{
          job_name = "journal";
          journal = {
            labels = {
              host = prefs.hostname;
              job = "systemd-journal";
            };
            max_age = "12h";
          };
          relabel_configs = [{
            source_labels = [ "__journal__systemd_unit" ];
            target_label = "unit";
          }];
        }] ++ lib.optionals prefs.enableTraefik [
          {
            job_name = "traefik";
            static_configs = [{
              targets = [ "localhost" ];
              labels = {
                __path__ = "/var/log/traefik/log.json";
                instance_node = prefs.hostname;
                job = "traefik";
              };
            }];
          }
          {
            job_name = "traefik-access";
            static_configs = [{
              targets = [ "localhost" ];
              labels = {
                __path__ = "/var/log/traefik/access.log.json";
                instance_node = prefs.hostname;
                job = "traefik-access";
              };
            }];
          }
        ];
      };
    };

    loki = {
      enable = prefs.enableLoki;
      configuration = {
        auth_enabled = false;
        chunk_store_config = { max_look_back_period = "0s"; };
        compactor = {
          shared_store = "filesystem";
          working_directory = "/var/lib/loki/boltdb-shipper-compactor";
        };
        ingester = {
          chunk_idle_period = "1h";
          chunk_retain_period = "30s";
          chunk_target_size = 1048576;
          lifecycler = {
            address = "127.0.0.1";
            final_sleep = "0s";
            ring = {
              kvstore = { store = "inmemory"; };
              replication_factor = 1;
            };
          };
          max_chunk_age = "1h";
          max_transfer_retries = 0;
          wal = {
            dir = "/var/lib/loki/wal";
            enabled = true;
          };
        };
        limits_config = {
          reject_old_samples = true;
          reject_old_samples_max_age = "168h";
        };
        ruler = {
          alertmanager_url = "http://localhost:9093";
          enable_api = true;
          ring = { kvstore = { store = "inmemory"; }; };
          rule_path = "/var/lib/loki/rules-temp";
          storage = {
            local = { directory = "/var/lib/loki/rules"; };
            type = "local";
          };
        };
        schema_config = {
          configs = [{
            from = "2020-10-24";
            index = {
              period = "24h";
              prefix = "index_";
            };
            object_store = "filesystem";
            schema = "v11";
            store = "boltdb-shipper";
          }];
        };
        server = {
          grpc_listen_port = prefs.lokiGrpcPort;
          http_listen_port = prefs.lokiHttpPort;
        };
        storage_config = {
          boltdb_shipper = {
            active_index_directory = "/var/lib/loki/boltdb-shipper-active";
            cache_location = "/var/lib/loki/boltdb-shipper-cache";
            cache_ttl = "24h";
            shared_store = "filesystem";
          };
          filesystem = { directory = "/var/lib/loki/chunks"; };
        };
        table_manager = {
          retention_deletes_enabled = false;
          retention_period = "0s";
        };
      };
    };

    autossh = {
      sessions = pkgs.lib.optionals (prefs.enableAutossh) (let
        go = server:
          let
            sshPort = if prefs.enableAioproxy then prefs.aioproxyPort else 22;
            autosshPorts = prefs.helpers.autossh {
              hostname = prefs.hostname;
              serverName = server;
            };
            extraArguments = let
              getReverseArgument = port:
                "-R :${builtins.toString port}:localhost:${
                  builtins.toString sshPort
                }";
              reversePorts = builtins.concatStringsSep " "
                (builtins.map (x: getReverseArgument x) autosshPorts);
            in "-o ServerAliveInterval=15 -o ServerAliveCountMax=4 -N ${reversePorts} ${server}";
          in {
            extraArguments = extraArguments;
            name = server;
            user = prefs.owner;
          };
      in map go prefs.autosshServers);
    };
    eternal-terminal = { enable = prefs.enableEternalTerminal; };
    printing = {
      enable = prefs.enablePrinting;
      drivers = [ pkgs.hplip ];
    };
    tailscale = { enable = prefs.enableTailScale; };
    zerotierone = {
      enable = prefs.buildZerotierone || prefs.enableZerotierone;
      joinNetworks = prefs.zerotieroneNetworks;
    };
    system-config-printer.enable = prefs.enablePrinting;
    logind = {
      lidSwitchExternalPower = "ignore";
      extraConfig = ''
        HandlePowerKey=suspend
        RuntimeDirectorySize=50%
      '';
    };
    postfix = {
      enable = prefs.enablePostfix;
      rootAlias = prefs.owner;
      extraConfig = ''
        myhostname = ${prefs.hostname}
        mydomain = localdomain
        mydestination = $myhostname, localhost.$mydomain, localhost
        mynetworks_style = host
      '';
    };
    traefik = {
      enable = prefs.enableTraefik;
      dynamicConfigOptions = {
        http = {
          serversTransports = {
            insecureSkipVerify = { insecureSkipVerify = true; };
          };
          routers = {
            traefik-dashboard = {
              rule = "${
                  getTraefikRuleByDomainPrefix "traefik"
                } && (PathPrefix(`/api`) || PathPrefix(`/dashboard`))";
              middlewares = [ "authelia@docker" ];
              entryPoints = [ "websecure" ];
              service = "api@internal";
              tls = { };
            };
            etesync-pim = {
              rule = getTraefikRuleByDomainPrefix "etesync-pim";
              service = "etesync-pim";
              tls = { };
            };
            etesync-notes = {
              rule = getTraefikRuleByDomainPrefix "etesync-notes";
              service = "etesync-notes";
              tls = { };
            };
            clash = {
              rule = getTraefikRuleByDomainPrefix "clash";
              middlewares = [ "authelia@docker" ];
              service = "clash";
              tls = { };
            };
            aria2rpc = {
              rule = "(${
                  getTraefikRuleByDomainPrefix "aria2"
                }) && PathPrefix(`/jsonrpc`)";
              service = "aria2rpc";
              tls = { };
            };
            aria2 = {
              rule = getTraefikRuleByDomainPrefix "aria2";
              middlewares = [ "aria2" ];
              service = "aria2";
              tls = { };
            };
            organice = {
              rule = getTraefikRuleByDomainPrefix "organice";
              service = "organice";
              tls = { };
            };
          } // lib.optionalAttrs prefs.ociContainers.enableHomer {
            homer = {
              rule = getTraefikBareDomainRule;
              service = "homer@docker";
              tls = { };
            };
          } // lib.optionalAttrs prefs.enableCodeServer {
            codeserver = {
              rule = getTraefikRuleByDomainPrefix "codeserver";
              service = "codeserver";
              middlewares = [ ];
              tls = { };
            };
          } // lib.optionalAttrs prefs.enableWstunnel {
            wstunnel-with-auth = {
              rule = "(${
                  getTraefikRuleByDomainPrefix "wstunnel"
                }) && !PathPrefix(`/{{ env `WSTUNNEL_PATH` }}`)";
              middlewares = [ "authelia@docker" "wstunnel" ];
              service = "dummy";
              tls = { };
            };
          } // lib.optionalAttrs prefs.enableWstunnel {
            wstunnel = {
              rule = "(${
                  getTraefikRuleByDomainPrefix "wstunnel"
                }) && PathPrefix(`/{{ env `WSTUNNEL_PATH` }}`)";
              service = "wstunnel";
              tls = { };
            };
          } // lib.optionalAttrs prefs.enableSyncthing {
            syncthing = {
              rule = getTraefikRuleByDomainPrefix "syncthing";
              service = "syncthing";
              middlewares = [ "authelia@docker" "syncthing" ];
              tls = { };
            };
          } // lib.optionalAttrs prefs.enableGrafana {
            grafana = {
              rule = getTraefikRuleByDomainPrefix "grafana";
              service = "grafana";
              tls = { };
            };
          } // lib.optionalAttrs prefs.enableSmosServer {
            smos = {
              rule = getTraefikRuleByDomainPrefix "smos";
              service = "smos";
              tls = { };
            };
            smos-api = {
              rule = getTraefikRuleByDomainPrefix "smos-api";
              service = "smos-api";
              tls = { };
            };
          } // lib.optionalAttrs prefs.enableActivityWatch {
            activitywatch = {
              rule = getTraefikRuleByDomainPrefix "activitywatch";
              service = "activitywatch";
              middlewares = [ "authelia@docker" ];
              tls = { };
            };
          } // lib.optionalAttrs prefs.enableTtyd {
            ttyd = {
              rule = getTraefikRuleByDomainPrefix "ttyd";
              service = "ttyd";
              tls = { };
            };
          };
          middlewares = {
            aria2 = {
              replacePathRegex = {
                regex = "^/(.*)";
                replacement = "/webui-aria2/$1";
              };
            };
            # Use this only for syncthing GUI (not restful api).
            syncthing = {
              headers = {
                customRequestHeaders = {
                  Authorization = "{{ env `SYNCTHING_AUTHORIZATION` }}";
                };
              };
            };
            wstunnel = {
              redirectRegex = {
                regex = "^https?://(.*?)/(.*)";
                replacement = "https://\${1}/{{ env `WSTUNNEL_PATH` }}";
              };
            };
            cors = {
              headers = {
                accessControlAllowMethods = [ "*" ];
                accessControlAllowHeaders = [ "*" ];
                accessControlAllowOriginListRegex =
                  let postfix = ".${prefs.mainDomain}";
                  in lib.optionals (prefs.mainDomain != "") [
                    "^.*${builtins.replaceStrings [ "." ] [ "\\." ] postfix}$"
                  ];
                accessControlMaxAge = 3600;
                addVaryHeader = true;
              };
            };
          };
          services = {
            # Dummy service to satisfy traefik (each route requires a service).
            dummy = {
              loadBalancer = {
                passHostHeader = false;
                servers =
                  [{ url = "https://${prefs.getFullDomainName "dummy"}"; }];
              };
            };
            etesync-pim = {
              loadBalancer = {
                passHostHeader = false;
                servers = [{ url = "https://pim.etesync.com/"; }];
              };
            };
            etesync-notes = {
              loadBalancer = {
                passHostHeader = false;
                servers = [{ url = "https://notes.etesync.com/"; }];
              };
            };
            clash = {
              loadBalancer = {
                passHostHeader = false;
                servers = [{ url = "https://clash.razord.top"; }];
              };
            };
            aria2rpc = {
              loadBalancer = {
                passHostHeader = false;
                servers = [{ url = "http://localhost:6800/"; }];
              };
            };
            aria2 = {
              loadBalancer = {
                passHostHeader = false;
                servers =
                  [{ url = "https://ziahamza.github.io/webui-aria2/"; }];
              };
            };
            organice = {
              loadBalancer = {
                passHostHeader = false;
                servers = [{ url = "https://organice.200ok.ch/"; }];
              };
            };
          } // lib.optionalAttrs prefs.enableCodeServer {
            codeserver = {
              loadBalancer = {
                servers = [{ url = "http://127.0.0.1:4050/"; }];
              };
            };
          } // lib.optionalAttrs prefs.enableWstunnel {
            wstunnel = {
              loadBalancer = {
                servers = [{
                  url =
                    "http://127.0.0.1:${builtins.toString prefs.wstunnelPort}/";
                }];
              };
            };
          } // lib.optionalAttrs prefs.enableSyncthing {
            syncthing = {
              loadBalancer = {
                passHostHeader = false;
                servers = [{ url = "http://127.0.0.1:8384/"; }];
              };
            };
          } // lib.optionalAttrs prefs.enableGrafana {
            grafana = {
              loadBalancer = {
                servers = [{
                  url =
                    "http://127.0.0.1:${toString config.services.grafana.port}";
                }];
              };
            };
          } // lib.optionalAttrs prefs.enableSmosServer {
            smos = {
              loadBalancer = {
                servers = [{
                  url = "http://localhost:${
                      builtins.toString
                      config.services.smos.production.web-server.port
                    }/";
                }];
              };
            };
            smos-api = {
              loadBalancer = {
                servers = [{
                  url = "http://localhost:${
                      builtins.toString
                      config.services.smos.production.api-server.port
                    }/";
                }];
              };
            };
          } // lib.optionalAttrs prefs.enableActivityWatch {
            activitywatch = {
              loadBalancer = {
                servers = [{ url = "http://localhost:5600/"; }];
              };
            };
          } // lib.optionalAttrs prefs.enableTtyd {
            ttyd = {
              loadBalancer = {
                passHostHeader = true;
                servers = [{
                  url = "http://localhost:${
                      builtins.toString config.services.ttyd.port
                    }/";
                }];
              };
            };
          };
        };
        tcp = {
          routers = {
            aioproxy = {
              rule = "HostSNI(`*`)";
              service = "aioproxy";
              tls = { };
            };
          };
          services = {
            aioproxy = {
              loadBalancer = {
                servers = [{
                  address = "127.0.0.1:${builtins.toString prefs.aioproxyPort}";
                }];
              };
            };
          };
        };
        tls = {
          certificates = [{
            certFile = "/var/lib/acme/${prefs.mainDomain}/cert.pem";
            keyFile = "/var/lib/acme/${prefs.mainDomain}/key.pem";
          }];
          stores = {
            default = {
              defaultCertificate = {
                certFile = "/var/lib/acme/${prefs.mainDomain}/cert.pem";
                keyFile = "/var/lib/acme/${prefs.mainDomain}/key.pem";
              };
            };
          };
        };
      };
      staticConfigOptions = {
        api = { dashboard = true; };
        entryPoints = let
          getEntrypoint = address: {
            address = address;
            proxyProtocol = {
              trustedIPs = [
                "127.0.0.0/8"
                "10.0.0.0/8"
                "100.64.0.0/10"
                "169.254.0.0/16"
                "172.16.0.0/12"
                "192.168.0.0/16"
              ];
            };
          };
        in {
          web = getEntrypoint ":80" // {
            http = {
              redirections = {
                entryPoint = {
                  to = "websecure";
                  scheme = "https";
                };
              };
            };
          };
          websecure = getEntrypoint ":443" // { http = { tls = { }; }; };
          metrics = {
            address = "127.0.0.1:${builtins.toString prefs.traefikMetricsPort}";
          };
        };
        log = {
          level = "INFO";
          filePath = "/var/log/traefik/log.json";
          format = "json";
        };
        accessLog = {
          filePath = "/var/log/traefik/access.log.json";
          format = "json";
        };
        metrics = {
          prometheus = {
            addEntryPointsLabels = true;
            entryPoint = "metrics";
          };
        };
        providers = {
          docker = {
            defaultRule = getTraefikRuleByDomainPrefix
              "{{ (or (index .Labels `domainprefix`) .Name) | normalize }}";
            endpoint = if (prefs.ociContainerBackend == "docker") then
              "unix:///var/run/docker.sock"
            else
              "unix:///var/run/podman/podman.sock";
            network = "${prefs.ociContainerNetwork}";
          };
        } // pkgs.lib.optionalAttrs (prefs.enableK3s) {
          kubernetesIngress = { };
        };
      };
    };
    postgresql = {
      enable = prefs.enablePostgresql;
      package = pkgs.postgresql_13;
      enableTCPIP = true;
      settings = {
        # password_encryption = "scram-sha-256";
      };
      authentication = ''
        host  all all 0.0.0.0/0 md5
        host  all all ::0/0 md5
      '';
      ensureDatabases = [ "nextcloud" "wallabag" ];
      ensureUsers = [
        {
          name = "nextcloud";
          ensurePermissions = { "DATABASE nextcloud" = "ALL PRIVILEGES"; };
        }
        {
          name = "wallabag";
          ensurePermissions = { "DATABASE wallabag" = "ALL PRIVILEGES"; };
        }
        {
          name = "superuser";
          ensurePermissions = {
            "ALL TABLES IN SCHEMA public" = "ALL PRIVILEGES";
          };
        }
      ];
    };
    postgresqlBackup = {
      enable = prefs.enablePostgresql;
      backupAll = true;
    };
    udisks2.enable = prefs.enableUdisks2;
    redis.enable = prefs.enableRedis;
    fail2ban.enable = prefs.enableFail2ban && config.networking.firewall.enable;
    mpd.enable = prefs.enableMpd;
    # mosquitto.enable = true;
    rsyncd.enable = prefs.enableRsyncd;
    # accounts-daemon.enable = prefs.enableAccountsDaemon || prefs.enableFlatpak;
    flatpak.enable = prefs.enableFlatpak;
    thermald = { enable = prefs.enableThermald; };
    gnome = { gnome-keyring.enable = prefs.enableGnomeKeyring; };

    locate = {
      enable = prefs.enableLocate;
      locate = pkgs.mlocate;
      localuser = null;
      interval = "hourly";
      pruneBindMounts = true;
    };

    # change port
    # sudo chown -R e /etc/rancher/k3s/
    # k3s kubectl patch service traefik -n kube-system -p '{"spec": {"ports": [{"port": 443,"targetPort": 443, "nodePort": 30443, "protocol": "TCP", "name": "https"},{"port": 80,"targetPort": 80, "nodePort": 30080, "protocol": "TCP", "name": "http"}], "type": "LoadBalancer"}}'
    k3s = let
      # https://github.com/NixOS/nixpkgs/issues/111835#issuecomment-784905827
      # Wait for k3s to support cgroup v2
      # https://github.com/NixOS/nixpkgs/blob/8823855ce36de32b8b9118ce87bfa5ff9a641657/nixos/modules/services/cluster/k3s/default.nix#L80-L81
      myArgs = "--no-deploy traefik";
    in {
      enable = prefs.enableK3s;
      extraFlags = myArgs;
    } // (if prefs.enableContainerd then {
      extraFlags = builtins.concatStringsSep " " [
        myArgs
        "--container-runtime-endpoint=/run/containerd/containerd.sock"
      ];
    } else if prefs.enableDocker then {
      docker = true;
    } else
      { });

    jupyterhub = {
      enable = prefs.enableJupyter;
      jupyterhubEnv = prefs.helpers.mkIfAttrExists pkgs "myPackages.jupyterhub";
      # TODO: the following will not produce the required binary like jupyterhub-singleuser
      # jupyterlabEnv = prefs.helpers.mkIfAttrExists pkgs "myPackages.jupyterlab";
      jupyterlabEnv = with pkgs;
        python3.withPackages
        (p: with p; [ jupyterhub jupyterlab jupyterlab_server ]);
      port = 8899;
      kernels = {
        python3Kernel = (let
          env = pkgs.python3.withPackages
            (p: with p; [ ipykernel dask-gateway numpy scipy ]);
        in {
          displayName = "Python 3";
          argv = [
            "${env.interpreter}"
            "-m"
            "ipykernel_launcher"
            "-f"
            "{connection_file}"
          ];
          language = "python";
          logo32 =
            "${env}/${env.sitePackages}/ipykernel/resources/logo-32x32.png";
          logo64 =
            "${env}/${env.sitePackages}/ipykernel/resources/logo-64x64.png";
        });

        cKernel = (let
          env = pkgs.python3.withPackages (p: with p; [ jupyter-c-kernel ]);
        in {
          displayName = "C";
          argv = [
            "${env.interpreter}"
            "-m"
            "jupyter_c_kernel"
            "-f"
            "{connection_file}"
          ];
          language = "c";
        });

        rustKernel = {
          displayName = "Rust";
          argv = [
            "${pkgs.evcxr}/bin/evcxr_jupyter"
            "--control_file"
            "{connection_file}"
          ];
          language = "Rust";
        };

        # rKernel = (let
        #   env = pkgs.rWrapper.override {
        #     packages = with pkgs.rPackages; [ IRkernel ggplot2 ];
        #   };
        # in {
        #   displayName = "R";
        #   argv = [
        #     "${env}/bin/R"
        #     "--slave"
        #     "-e"
        #     "IRkernel::main()"
        #     "--args"
        #     "{connection_file}"
        #   ];
        #   language = "R";
        # });

        # ansibleKernel = (let
        #   env = (pkgs.python3.withPackages
        #     (p: with p; [ ansible-kernel ansible ])).override
        #     (args: { ignoreCollisions = true; });
        # in {
        #   displayName = "Ansible";
        #   argv = [
        #     "${env.interpreter}"
        #     "-m"
        #     "ansible_kernel"
        #     "-f"
        #     "{connection_file}"
        #   ];
        #   language = "ansible";
        # });

        bashKernel =
          (let env = pkgs.python3.withPackages (p: with p; [ bash_kernel ]);
          in {
            displayName = "Bash";
            argv = [
              "${env.interpreter}"
              "-m"
              "bash_kernel"
              "-f"
              "{connection_file}"
            ];
            language = "Bash";
          });

        nixKernel =
          (let env = pkgs.python3.withPackages (p: with p; [ nix-kernel ]);
          in {
            displayName = "Nix";
            argv = [
              "${env.interpreter}"
              "-m"
              "nix-kernel"
              "-f"
              "{connection_file}"
            ];
            language = "Nix";
          });

        rubyKernel = {
          displayName = "Ruby";
          argv = [ "${pkgs.iruby}/bin/iruby" "kernel" "{connection_file}" ];
          language = "ruby";
        };

        # TODO: Below build failed with
        # RPATH of binary /nix/store/ilhgzcydg3vn4mp7k5yawlsjwfpm8xi8-ihaskell-0.10.1.2/bin/ihaskell contains a forbidden reference to /build/
        #   haskellKernel = (let
        #     env = pkgs.haskellPackages.ghcWithPackages (pkgs: [ pkgs.ihaskell ]);
        #     ihaskellSh = pkgs.writeScriptBin "ihaskell" ''
        #       #! ${pkgs.stdenv.shell}
        #       export GHC_PACKAGE_PATH="$(echo ${env}/lib/*/package.conf.d| tr ' ' ':'):$GHC_PACKAGE_PATH"
        #       export PATH="${pkgs.stdenv.lib.makeBinPath ([ env ])}:$PATH"
        #       ${env}/bin/ihaskell -l $(${env}/bin/ghc --print-libdir) "$@"
        #     '';
        #   in {
        #     displayName = "Haskell";
        #     argv = [
        #       "${ihaskellSh}/bin/ihaskell"
        #       "kernel"
        #       "{connection_file}"
        #       "+RTS"
        #       "-M3g"
        #       "-N2"
        #       "-RTS"
        #     ];
        #     language = "Haskell";
        #   });
      };
    };

    cfssl = {
      enable = prefs.enableCfssl;
      ca = "file:/run/secrets/cfssl-ca-pem";
      caKey = "file:/run/secrets/cfssl-ca-key-pem";
    };

    sslh = {
      enable = prefs.enableSslh;
      port = prefs.sslhPort;
      transparent = false;
      verbose = true;
    } // (let p = impure.sslhConfigFile;
    in pkgs.lib.optionalAttrs (builtins.pathExists p) {
      appendConfig = (builtins.readFile p);
    });

    unifi.enable = prefs.enableUnifi;

    gvfs.enable = prefs.enableGvfs;

    emacs = {
      enable = prefs.enableEmacs;
      install = prefs.enableEmacs;
      package = pkgs.myPackages.emacs or pkgs.emacs;
    };

    syncthing = let
      devices = {
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
        };
        gcv = {
          id =
            "X7QL3PP-FEKIMHT-BAVJIR5-YX77J26-42XWIJW-S5H2FCF-RIKRKB5-RU3XRAB";
        };
      };
    in {
      enable = prefs.enableSyncthing;
      user = prefs.owner;
      dataDir = prefs.home;
      extraOptions = {
        gui = {
          user = "e";
          # TODO: didn't find way to hide it, but this password has enough entropy.
          password =
            "$2a$10$20ol/13Gghbqq/tsEkEyGO.kJLgKsz2cJmC4Cccx.0Z1ECSYHO80O";
        };
        # I need allowedNetwork so I will use extraOptions instead of devices.
        devices = let
          mkDevice = { name, id, introducer ? true
            , allowedNetworks ? [ "!10.144.0.0/16" "0.0.0.0/0" "::/0" ], ...
            }: {
              deviceID = id;
              inherit name introducer allowedNetworks;
            };
          list = lib.mapAttrsToList (name: value: value // { inherit name; })
            devices;
        in builtins.map mkDevice list;
      };

      inherit devices;

      folders = let
        allDevices = builtins.attrNames devices;
        getVersioningPolicy = id: {
          type = "staggered";
          # TODO: This does not work. Syncthing seems to be using new schema now.
          # See https://github.com/syncthing/syncthing/pull/7407
          # cleanIntervalS = 3600;
          # fsPath = "${prefs.home}/.cache/syncthing_versioning/${id}";
          # fsType = "basic";
          params = {
            cleanInterval = "3600";
            maxAge = "315360000";
          };
        };
        getFolderConfig = { id, path, excludedDevices ? [ ] }: rec {
          inherit id path;
          devices = lib.subtractLists excludedDevices allDevices;
          ignorePerms = false;
          versioning = getVersioningPolicy id;
        };
      in {
        "${prefs.calibreFolder}" = getFolderConfig {
          id = "calibre";
          path = prefs.calibreFolder;
        };

        "${prefs.syncFolder}" = getFolderConfig {
          id = "sync";
          path = prefs.syncFolder;
        };
      };
    };

    # yandex-disk = { enable = prefs.enableYandexDisk; } // yandexConfig;

    xserver = {
      enable = prefs.enableXserver;
      verbose = 7;
      autorun = true;
      exportConfiguration = true;
      layout = "us";
      dpi = prefs.dpi;
      libinput = {
        enable = prefs.enableLibInput;
        touchpad = {
          tapping = true;
          disableWhileTyping = true;
        };
      };
      # videoDrivers = [ "dummy" ] ++ [ "intel" ];
      virtualScreen = {
        x = 1200;
        y = 1920;
      };
      xautolock = let
        locker = "${pkgs.i3lock}/bin/i3lock";
        killer = "${pkgs.systemd}/bin/systemctl suspend";
        notifier =
          ''${pkgs.libnotify}/bin/notify-send "Locking in 10 seconds"'';
      in {
        inherit locker killer notifier;
        enable = prefs.enableXautolock;
        enableNotifier = true;
        nowlocker = locker;
      };
      # desktopManager.xfce.enable = true;
      desktopManager.gnome.enable = prefs.enableGnome;
      # desktopManager.plasma5.enable = true;
      # desktopManager.xfce.enableXfwm = false;
      windowManager = {
        i3 = {
          enable = true;
          package = pkgs.i3-gaps;
        };
        awesome.enable = true;
      } // (if (prefs.enableXmonad) then {
        xmonad = {
          enable = true;
          enableContribAndExtras = true;
          extraPackages = haskellPackages:
            with haskellPackages; [
              xmobar
              # taffybar
              xmonad-contrib
              xmonad-extras
              xmonad-utils
              # xmonad-windownames
              xmonad-entryhelper
              yeganesh
              libmpd
              dbus
            ];
        };
      } else
        { });
      displayManager = let
        defaultSession = prefs.xDefaultSession;
        autoLogin = {
          enable = prefs.enableAutoLogin;
          user = prefs.owner;
        };
      in {
        sessionCommands = prefs.xSessionCommands;
        startx = { enable = prefs.enableStartx; };
        sddm = {
          enable = prefs.enableSddm;
          enableHidpi = prefs.enableHidpi;
          autoNumlock = true;
        };
        gdm = { enable = prefs.enableGdm; };
        lightdm = { enable = prefs.enableLightdm; };
      };
    };
  };

  # xdg.portal.enable = prefs.enableXdgPortal || prefs.enableFlatpak;

  users = builtins.foldl' (a: e: pkgs.lib.recursiveUpdate a e) { } [
    {
      users = let
        extraGroups = [
          "wheel"
          "cups"
          "video"
          "kvm"
          "libvirtd"
          "qemu-libvirtd"
          "audio"
          "disk"
          "keys"
          "aria2"
          "networkmanager"
          "adbusers"
          "docker"
          "davfs2"
          "wireshark"
          "vboxusers"
          "lp"
          "input"
          "mlocate"
          "postfix"
        ];
      in {
        "${prefs.owner}" = {
          createHome = true;
          inherit extraGroups;
          group = prefs.ownerGroup;
          home = prefs.home;
          isNormalUser = true;
          uid = prefs.ownerUid;
          shell = if prefs.enableZSH then pkgs.zsh else pkgs.bash;
          initialHashedPassword =
            "$6$eE6pKPpxdZLueg$WHb./PjNICw7nYnPK8R4Vscu/Rw4l5Mk24/Gi4ijAsNP22LG9L471Ox..yUfFRy5feXtjvog9DM/jJl82VHuI1";
        };
      };
      groups = { "${prefs.ownerGroup}" = { gid = prefs.ownerGroupGid; }; };
    }
    {
      users = {
        clash = {
          group = "clash";
          createHome = false;
          isNormalUser = false;
          isSystemUser = true;
        };
      };
      groups = { clash = { name = "clash"; }; };
    }
    (lib.optionalAttrs prefs.enableFallbackAccount {
      users = {
        # Fallback user when "${prefs.owner}" encounters problems
        fallback = {
          group = "fallback";
          createHome = true;
          isNormalUser = true;
          useDefaultShell = true;
          initialHashedPassword =
            "$6$nstJFDdZZ$uENeWO2lup09Je7UzVlJpwPlU1SvLwzTrbm/Gr.4PUpkKUuGcNEFmUrfgotWF3HoofVrGg1ENW.uzTGT6kX3v1";
        };
      };
      groups = { fallback = { name = "fallback"; }; };
    })
  ];

  virtualisation = {
    libvirtd = { enable = prefs.enableLibvirtd; };
    virtualbox.host = {
      enable = prefs.enableVirtualboxHost;
      enableExtensionPack = prefs.enableVirtualboxHost;
      # enableHardening = false;
    };
    containerd = { enable = prefs.enableContainerd; };
    cri-o = { enable = prefs.enableCrio; };
    podman = {
      enable = prefs.enablePodman
        || (prefs.enableOciContainers && prefs.ociContainerBackend == "podman");
      dockerCompat = prefs.replaceDockerWithPodman;
      extraPackages = if (prefs.enableZfs) then [ pkgs.zfs ] else [ ];
    };
    docker = {
      enable = prefs.enableDocker && !prefs.replaceDockerWithPodman;
      autoPrune.enable = true;
    };
    anbox = { enable = prefs.enableAnbox; };
    oci-containers = let
      mkContainer = name: enable: config:
        pkgs.lib.optionalAttrs enable (let
          images = let
            postgresql = {
              "x86_64-linux" = "docker.io/postgres:13";
              "aarch64-linux" = "docker.io/arm64v8/postgres:13";
            };
            hledger = { "x86_64-linux" = "docker.io/dastapov/hledger:latest"; };
          in {
            "postgresql" = postgresql;
            "postgresql-init" = postgresql;
            "redis" = {
              "x86_64-linux" = "docker.io/redis:6";
              "aarch64-linux" = "docker.io/arm64v8/redis:6";
            };
            "authelia" = {
              "x86_64-linux" = "docker.io/authelia/authelia:4";
              "aarch64-linux" = "docker.io/authelia/authelia:4";
            };
            "hledger" = hledger;
            "hledger-init" = hledger;
            "searx" = {
              "x86_64-linux" = "docker.io/searxng/searxng:latest";
              "aarch64-linux" = "docker.io/searxng/searxng:latest";
            };
            "rss-bridge" = let image = "docker.io/rssbridge/rss-bridge:latest";
            in {
              "x86_64-linux" = image;
              "aarch64-linux" = image;
            };
            "wallabag" = {
              "x86_64-linux" = "docker.io/wallabag/wallabag:2.4.2";
              "aarch64-linux" = "docker.io/ugeek/wallabag:arm-2.4";
            };
            "recipes" = let image = "docker.io/vabene1111/recipes:latest";
            in {
              "x86_64-linux" = image;
              "aarch64-linux" = image;
            };
            "wger" = let image = "docker.io/wger/apache:2.0-dev";
            in { "x86_64-linux" = image; };
            "freeipa" = {
              "x86_64-linux" =
                "docker.io/freeipa/freeipa-server:fedora-rawhide";
              "aarch64-linux" =
                "docker.io/blackheat/freeipa-server:fedora-34-4.9.6";
            };
            "cloudbeaver" = {
              "x86_64-linux" = "docker.io/dbeaver/cloudbeaver:latest";
            };
            "n8n" = {
              "x86_64-linux" = "docker.io/n8nio/n8n:latest";
              "aarch64-linux" = "docker.io/n8nio/n8n:latest-rpi";
            };
            "gitea" = let image = "docker.io/gitea/gitea:latest";
            in {
              "x86_64-linux" = image;
              "aarch64-linux" = image;
            };
            "vault" = let image = "docker.io/vault:latest";
            in {
              "x86_64-linux" = image;
              "aarch64-linux" = image;
            };
            "wikijs" = let image = "docker.io/requarks/wiki:2";
            in {
              "x86_64-linux" = image;
              "aarch64-linux" = image;
            };
            "grocy" = let image = "docker.io/linuxserver/grocy:latest";
            in {
              "x86_64-linux" = image;
              "aarch64-linux" = image;
            };
            "calibre-web" =
              let image = "docker.io/linuxserver/calibre-web:latest";
              in {
                "x86_64-linux" = image;
                "aarch64-linux" = image;
              };
            "dokuwiki" = let image = "docker.io/linuxserver/dokuwiki:latest";
            in {
              "x86_64-linux" = image;
              "aarch64-linux" = image;
            };
            "trilium" = {
              "x86_64-linux" = "docker.io/zadam/trilium:latest";
              "aarch64-linux" = "docker.io/hlince/trilium:latest";
            };
            "xwiki" = let image = "docker.io/xwiki:lts-postgres-tomcat";
            in {
              "x86_64-linux" = image;
              "aarch64-linux" = image;
            };
            "huginn" = {
              "x86_64-linux" = "docker.io/huginn/huginn:latest";
              "aarch64-linux" = "docker.io/zhorvath83/huginn:latest";
            };
            "tiddlywiki" = let image = "docker.io/contrun/tiddlywiki:latest";
            in {
              "x86_64-linux" = image;
              "aarch64-linux" = image;
            };
            "vaultwarden" = let image = "docker.io/vaultwarden/server:latest";
            in {
              "x86_64-linux" = image;
              "aarch64-linux" = image;
            };
            "pleroma" =
              let image = "git.pleroma.social:5050/pleroma/pleroma:latest";
              in {
                "x86_64-linux" = image;
                "aarch64-linux" = image;
              };
            "joplin" = let image = "docker.io/florider89/joplin-server:master";
            in {
              "x86_64-linux" = image;
              "aarch64-linux" = image;
            };
            "miniflux" = let image = "docker.io/miniflux/miniflux:latest";
            in {
              "x86_64-linux" = image;
              "aarch64-linux" = image;
            };
            "nextcloud" = let image = "docker.io/nextcloud:latest";
            in {
              "x86_64-linux" = image;
              "aarch64-linux" = image;
            };
            "sftpgo" = let image = "ghcr.io/drakkan/sftpgo:latest";
            in {
              "x86_64-linux" = image;
              "aarch64-linux" = image;
            };
            "filestash" = let image = "docker.io/machines/filestash:latest";
            in { "x86_64-linux" = image; };
            "homer" = let image = "docker.io/b4bz/homer:latest";
            in {
              "x86_64-linux" = image;
              "aarch64-linux" = image;
            };
            "etesync" = let image = "docker.io/victorrds/etesync:latest";
            in {
              "x86_64-linux" = image;
              "aarch64-linux" = image;
            };
            "etesync-dav" = let image = "docker.io/etesync/etesync-dav:latest";
            in { "x86_64-linux" = image; };
            "keeweb" =
              let image = "docker.io/contrun/keeweb-local-server:latest";
              in {
                "x86_64-linux" = image;
                "aarch64-linux" = image;
              };
            "codeserver" = let image = "docker.io/codercom/code-server:latest";
            in {
              "x86_64-linux" = image;
              "aarch64-linux" = image;
            };
          };
          f = { enableTraefik ? true, enableTraefikTls ? true
            , traefikForwardingPort ? 80, entrypoints ? [ "web" "websecure" ]
            , middlewares ? [ ], networkName ? prefs.ociContainerNetwork, ...
            }@args:
            args // {
              image =
                args.image or (images."${name}"."${prefs.nixosSystem}" or (builtins.throw
                  "Image for ${name} on ${prefs.nixosSystem} not found"));
              extraOptions = (args.extraOptions or [ ])
                ++ (if enableTraefik then
                  [
                    "--label=traefik.http.routers.${name}.service=${name}"
                    "--label=traefik.http.services.${name}.loadbalancer.server.port=${
                      builtins.toString traefikForwardingPort
                    }"
                  ] ++ (lib.optionals (entrypoints != [ ]) [
                    "--label=traefik.http.routers.${name}.entrypoints=${
                      builtins.concatStringsSep "," entrypoints
                    }"
                  ]) ++ (lib.optionals (middlewares != [ ]) [
                    "--label=traefik.http.routers.${name}.middlewares=${
                      builtins.concatStringsSep "," middlewares
                    }"
                  ]) ++ (lib.optionals (enableTraefikTls)
                    [ "--label=traefik.http.routers.${name}.tls=true" ])
                else
                  [ "--label=traefik.enable=false" ])
                ++ (lib.optionals (networkName != null)
                  [ "--network=${networkName}" ]);
            };
          getConfig = config:
            builtins.removeAttrs (f config) [
              "enableTraefik"
              "enableTraefikTls"
              "traefikForwardingPort"
              "entrypoints"
              "middlewares"
              "networkName"
            ];
        in { "${name}" = getConfig config; });
    in pkgs.lib.optionalAttrs prefs.enableOciContainers {
      backend = prefs.ociContainerBackend;
      containers =
        mkContainer "postgresql" prefs.ociContainers.enablePostgresql {
          volumes = [ "/var/data/postgresql:/var/lib/postgresql/data" ];
          ports = [ "5432:5432" ];
          environmentFiles = [ "/run/secrets/postgresql-env" ];
          enableTraefik = false;
        }
        // mkContainer "postgresql-init" prefs.ociContainers.enablePostgresql {
          volumes =
            [ "/run/secrets/postgresql-initdb-script:/my/init-user-db.sh" ];
          dependsOn = [ "postgresql" ];
          environmentFiles = [
            "/run/secrets/postgresql-env"
            "/run/secrets/postgresql-backup-env"
          ];
          entrypoint = "/my/init-user-db.sh";
          enableTraefik = false;
        } // mkContainer "redis" prefs.ociContainers.enableRedis {
          # https://stackoverflow.com/questions/42248198/how-to-mount-a-single-file-in-a-volume
          extraOptions = [
            "--mount"
            "type=bind,source=/run/secrets/redis-conf,target=/etc/redis.conf,readonly"
          ];
          ports = [ "6379:6379" ];
          cmd = [ "redis-server" "/etc/redis.conf" ];
          enableTraefik = false;
        } // mkContainer "authelia" prefs.ociContainers.enableAuthelia (let
          configs = ([ "authelia-conf" ]
            ++ (lib.optionals prefs.ociContainers.enableAutheliaLocalUsers
              [ "authelia-local-users-conf" ])
            ++ (lib.optionals (!prefs.ociContainers.enableAutheliaLocalUsers)
              [ "authelia-ldap-users-conf" ])
            ++ (lib.optionals prefs.ociContainers.enablePostgresql
              [ "authelia-postgres-conf" ])
            ++ (lib.optionals (!prefs.ociContainers.enablePostgresql)
              [ "authelia-sqlite-conf" ])
            ++ (lib.optionals prefs.ociContainers.enableRedis
              [ "authelia-redis-conf" ]));
        in {
          volumes = [ "/var/data/authelia:/config" ];
          cmd =
            lib.concatMap (x: [ "--config" ] ++ [ "/myconfig/${x}" ]) configs;
          environment = {
            AUTHELIA_DEFAULT_REDIRECTION_URL = "https://${prefs.domain}";
            AUTHELIA_TOTP_ISSUER = prefs.getFullDomainName "authelia";
          };
          extraOptions = (builtins.map (x:
            "--mount=type=bind,source=/run/secrets/${x},target=/myconfig/${x}")
            ([ "authelia-users" ] ++ configs)) ++ [
              "--label=traefik.http.middlewares.authelia.forwardauth.address=http://localhost:9091/api/verify?rd=https://${
                prefs.getFullDomainName "authelia"
              }"
              "--label=traefik.http.middlewares.authelia.forwardauth.trustForwardHeader=true"
              "--label=traefik.http.middlewares.authelia.forwardauth.authResponseHeaders=Remote-User,Remote-Groups,Remote-Name,Remote-Email"
              "--label=traefik.http.middlewares.authelia-basic.forwardauth.address=http://localhost:9091/api/verify?auth=basic"
              "--label=traefik.http.middlewares.authelia-basic.forwardauth.trustForwardHeader=true"
              "--label=traefik.http.middlewares.authelia-basic.forwardauth.authResponseHeaders=Remote-User,Remote-Groups,Remote-Name,Remote-Email"
            ];
          ports = [ "9091:9091" ];
          traefikForwardingPort = 9091;
        }) // mkContainer "freeipa" prefs.ociContainers.enableFreeipa {
          extraOptions = [
            "-h"
            "freeipa.home.arpa"
            "--sysctl"
            "net.ipv6.conf.lo.disable_ipv6=0"
            "--label=traefik.http.services.freeipa.loadbalancer.server.scheme=https"
            "--label=traefik.http.services.freeipa.loadbalancer.serverstransport=insecureSkipVerify@file"
          ];
          environment = {
            IPA_SERVER_INSTALL_OPTS =
              "--ds-password=The-directory-server-password --admin-password=The-admin-password";
          };
          cmd = [
            "ipa-server-install"
            "-U"
            "--no-ntp"
            "--domain"
            "freeipa.home.arpa"
            "--realm=HOME.ARPA"
          ];
          volumes = [ "/var/data/freeipa:/data:Z" ]
            ++ (if prefs.ociContainerBackend == "docker" then
              [ "/sys/fs/cgroup:/sys/fs/cgroup:ro" ]
            else
              [ ]);
          traefikForwardingPort = 443;
        } // mkContainer "cloudbeaver" prefs.ociContainers.enableCloudBeaver {
          volumes =
            [ "/var/data/cloudbeaver/workspace:/opt/cloudbeaver/workspace" ];
          traefikForwardingPort = 8978;
          middlewares = [ "authelia" ];
        } // mkContainer "hledger" prefs.ociContainers.enableHledger {
          dependsOn = [ "hledger-init" ];
          volumes = [ "/var/data/hledger:/data" ];
          traefikForwardingPort = 5000;
          middlewares = [ "authelia-basic" ];
          environment = {
            "HLEDGER_BASE_URL" = "https://${prefs.getFullDomainName "hledger"}";
            "HLEDGER_CAPABILITIES" = "view,add,manage";
          };
        } // mkContainer "hledger-init" prefs.ociContainers.enableHledger {
          volumes = [ "/var/data/hledger:/data" ];
          cmd = [
            "bash"
            "-c"
            "sudo chown -R $(id -u) /data; echo . | hledger add -f /data/hledger.journal --no-new-accounts"
          ];
          enableTraefik = false;
        } // mkContainer "searx" prefs.ociContainers.enableSearx {
          environment = {
            # Generate a new searx configuration, otherwise searx will not auto use the generated config.
            "SEARX_SETTINGS_PATH" = "/searx.settings.yml";
            # Currently does not work, https://github.com/searxng/searxng/blob/332e3a2a09d6a708ea2c17d2e731335b051c45aa/dockerfiles/docker-entrypoint.sh#L71
            # assumes the default instance name is searx, which is not true for searxng.
            "INSTANCE_NAME" = "searx@${prefs.domainPrefix}";
            "AUTOCOMPLETE" = "duckduckgo";
            "BASE_URL" = "https://${prefs.getFullDomainName "searx"}";
          };
          volumes = [ "/var/data/searx:/etc/searx" ];
          traefikForwardingPort = 8080;
          # middlewares = [ "authelia" ];
        } // mkContainer "rss-bridge" prefs.ociContainers.enableRssBridge {
          extraOptions = [
            "--mount"
            "type=bind,source=/run/secrets/rss-bridge-whitelist,target=/app/whitelist.txt"
          ];
          traefikForwardingPort = 80;
        } // mkContainer "wallabag" prefs.ociContainers.enableWallabag {
          dependsOn = [ "postgresql" ];
          environment = {
            "SYMFONY__ENV__DOMAIN_NAME" =
              "https://${prefs.getFullDomainName "wallabag"}";
          };
          volumes = [
            "/var/data/wallabag/data:/var/www/wallabag/data"
            "/var/data/wallabag/images:/var/www/wallabag/web/assets/images"
          ];
          environmentFiles = [ "/run/secrets/wallabag-env" ];
        } // mkContainer "recipes" prefs.ociContainers.enableRecipes {
          volumes = [
            "/var/data/recipes/staticfiles:/opt/recipes/staticfiles"
            "/var/data/recipes/mediafiles:/opt/recipes/mediafiles"
          ];
          dependsOn = [ "postgresql" ];
          environmentFiles = [ "/run/secrets/recipes-env" ];
          traefikForwardingPort = 8080;
        } // mkContainer "wger" prefs.ociContainers.enableWger {
          volumes = [ "/var/data/wger/media:/home/wger/media" ];
          dependsOn = [ "postgresql" ];
          environment = {
            "SITE_URL" = "https://${prefs.getFullDomainName "wger"}";
          };
          environmentFiles = [ "/run/secrets/wger-env" ];
          traefikForwardingPort = 80;
        } // mkContainer "n8n" prefs.ociContainers.enableN8n {
          volumes = [ "/var/data/n8n:/home/node/.n8n" ];
          dependsOn = [ "postgresql" ];
          middlewares = [ "authelia" ];
          environmentFiles = [ "/run/secrets/n8n-env" ];
          traefikForwardingPort = 5678;
        } // mkContainer "wikijs" prefs.ociContainers.enableWikijs {
          environmentFiles = [ "/run/secrets/wikijs-env" ];
          traefikForwardingPort = 3000;
        } // mkContainer "grocy" prefs.ociContainers.enableGrocy {
          volumes = [ "/var/data/grocy:/config" ];
          environment = {
            "PUID" = "${builtins.toString prefs.ownerUid}";
            "PGID" = "${builtins.toString prefs.ownerGroupGid}";
            "TZ" = "Asia/Shanghai";
            "GROCY_CURRENCY" = "CNY";
            "GROCY_MODE" = "production";
          };
          traefikForwardingPort = 80;
        } // mkContainer "calibre-web" prefs.ociContainers.enableCalibreWeb {
          volumes = [
            "/var/data/calibre-web:/config"
            "${builtins.elemAt prefs.calibreServerLibraries 0}:/books"
          ];
          extraOptions = [ "--label=domainprefix=calibre" ];
          environment = {
            "PUID" = "${builtins.toString prefs.ownerUid}";
            "PGID" = "${builtins.toString prefs.ownerGroupGid}";
            "TZ" = "Asia/Shanghai";
            "DOCKER_MODS" = "linuxserver/calibre-web:calibre";
          };
          traefikForwardingPort = 8083;
        } // mkContainer "dokuwiki" prefs.ociContainers.enableDokuwiki {
          volumes = [
            "/var/data/dokuwiki:/config"
            "${builtins.elemAt prefs.calibreServerLibraries 0}:/books"
          ];
          environment = {
            "PUID" = "${builtins.toString prefs.ownerUid}";
            "PGID" = "${builtins.toString prefs.ownerGroupGid}";
            "TZ" = "Asia/Shanghai";
            "DOCKER_MODS" = "linuxserver/calibre-web:calibre";
          };
          traefikForwardingPort = 80;
        } // mkContainer "trilium" prefs.ociContainers.enableTrilium {
          volumes = [ "/var/data/trilium:/home/node/trilium-data" ];
          traefikForwardingPort = 8080;
        } // mkContainer "xwiki" prefs.ociContainers.enableXwiki {
          dependsOn = [ "postgresql" ];
          environmentFiles = [ "/run/secrets/xwiki-env" ];
          volumes = [ "/var/data/xwiki:/usr/local/xwiki" ];
          traefikForwardingPort = 8080;
        } // mkContainer "huginn" prefs.ociContainers.enableHuginn {
          dependsOn = [ "postgresql" ];
          environmentFiles = [ "/run/secrets/huginn-env" ];
          traefikForwardingPort = 3000;
          environment = {
            "TIMEZONE" = "Beijing";
            "DOMAIN" = "https://${prefs.getFullDomainName "huginn"}";
          };
        } // mkContainer "tiddlywiki" prefs.ociContainers.enableTiddlyWiki {
          volumes = [ "/var/data/tiddlywiki:/tiddlywiki" ];
          extraOptions = [
            "--user=${builtins.toString prefs.ownerUid}:${
              builtins.toString prefs.ownerGroupGid
            }"
          ];
          cmd = [ "--listen" "host=0.0.0.0" ];
          middlewares = [ "authelia" ];
          traefikForwardingPort = 8080;
        } // mkContainer "gitea" prefs.ociContainers.enableGitea {
          volumes = [
            "/var/data/gitea:/data"
            "/etc/timezone:/etc/timezone:ro"
            "/etc/localtime:/etc/localtime:ro"
          ];
          dependsOn = [ "postgresql" ];
          environment = {
            "PUID" = "${builtins.toString prefs.ownerUid}";
            "PGID" = "${builtins.toString prefs.ownerGroupGid}";
            "USER_UID" = "${builtins.toString prefs.ownerUid}";
            "USER_GID" = "${builtins.toString prefs.ownerGroupGid}";
            "TZ" = "Asia/Shanghai";
            "GITEA__server__DOMAIN" = prefs.getFullDomainName "gitea";
            "GITEA__server__ROOT_URL" =
              "https://${prefs.getFullDomainName "gitea"}";
          };
          environmentFiles = [ "/run/secrets/gitea-env" ];
          traefikForwardingPort = 3000;
        } // mkContainer "vaultwarden" prefs.ociContainers.enableVaultwarden {
          dependsOn = [ "postgresql" ];
          volumes = [ "/var/data/vaultwarden:/data" ];
          environment = {
            "DOMAIN" = "https://${prefs.getFullDomainName "vaultwarden"}";
          };
          environmentFiles = [ "/run/secrets/vaultwarden-env" ];
          traefikForwardingPort = 80;
        } // mkContainer "pleroma" prefs.ociContainers.enablePleroma {
          dependsOn = [ "postgresql" ];
          volumes = [ "/var/data/pleroma:/var/lib/pleroma" ];
          environment = { "DOMAIN" = prefs.getFullDomainName "pleroma"; };
          environmentFiles = [ "/run/secrets/pleroma-env" ];
          traefikForwardingPort = 4000;
        } // mkContainer "joplin" prefs.ociContainers.enableJoplin {
          dependsOn = [ "postgresql" ];
          environment = {
            "APP_BASE_URL" = "https://${prefs.getFullDomainName "joplin"}";
          };
          environmentFiles = [ "/run/secrets/joplin-env" ];
          traefikForwardingPort = 22300;
        } // mkContainer "miniflux" prefs.ociContainers.enableMiniflux {
          dependsOn = [ "postgresql" ];
          environment = {
            "BASE_URL" = "https://${prefs.getFullDomainName "miniflux"}";
          };
          environmentFiles = [ "/run/secrets/miniflux-env" ];
          traefikForwardingPort = 8080;
        } // mkContainer "nextcloud" prefs.ociContainers.enableNextcloud {
          # Need to initialize the database manually,
          # cat $(systemctl cat docker-nextcloud.service | awk -F= '/ExecStart=/ {print $2}') | grep -v nextcloud-data
          # see also https://help.nextcloud.com/t/the-username-is-already-being-used-after-reinstalling-nextcloud-version-20-0-7-1/108219/3
          dependsOn =
            lib.optionals prefs.ociContainers.enablePostgresql [ "postgresql" ]
            ++ lib.optionals prefs.ociContainers.enableRedis [ "redis" ];
          # TODO: We need to periodically run `./occ files:scan --all` to keep
          # nextcloud database and the underlying directory tree structure in synchronization.
          # see https://github.com/nextcloud/server/issues/17550
          volumes = [
            "/var/data/nextcloud:/var/www/html"
            "${prefs.nextcloudContainerDataDirectory}:/var/www/html/data"
          ];
          environment = {
            "NEXTCLOUD_TRUSTED_DOMAINS" = "${builtins.concatStringsSep " "
              (prefs.getFullDomainNames "nextcloud")}";
          };
          environmentFiles = [ "/run/secrets/nextcloud-env" ]
            ++ (if prefs.ociContainers.enablePostgresql then
              [ "/run/secrets/nextcloud-postgres-env" ]
            else
              [ "/run/secrets/nextcloud-sqlite-env" ])
            ++ (lib.optionals prefs.ociContainers.enableRedis
              [ "/run/secrets/nextcloud-redis-env" ]);
          traefikForwardingPort = 80;
        } // mkContainer "sftpgo" prefs.ociContainers.enableSftpgo {
          extraOptions = [
            "--user=${builtins.toString prefs.ownerUid}:${
              builtins.toString prefs.ownerGroupGid
            }"
            "--label=traefik.http.routers.sftpgo-webdav.service=sftpgo-webdav"
            "--label=traefik.http.routers.sftpgo-webdav.middlewares=cors@file"
            "--label=traefik.http.routers.sftpgo-webdav.entrypoints=web,websecure"
            "--label=traefik.http.routers.sftpgo-webdav.rule=${
              getTraefikRuleByDomainPrefix "webdav"
            }"
            "--label=traefik.http.services.sftpgo-webdav.loadbalancer.server.port=10080"
          ];
          ports = [ "2122:2022" ];
          volumes = [
            "/var/data/sftpgo/config:/var/lib/sftpgo"
            "/var/data/sftpgo/data:/srv/sftpgo/data"
            "${prefs.home}:/srv/sftpgo/data/${prefs.owner}"
            "${prefs.syncFolder}:/srv/sftpgo/data/sync"
            "${prefs.syncFolder}/private/keepass:/srv/sftpgo/data/keepass"
            "${prefs.syncFolder}/docs/org-mode:/srv/sftpgo/data/orgmode"
            "/var/data/sftpgo/backups:/srv/sftpgo/backups"
          ];
          environment = {
            "SFTPGO_WEBDAVD__BINDINGS__0__PORT" = "10080";
            "SFTPGO_WEBDAVD__CORS__ENABLED" = "true";
            "SFTPGO_WEBDAVD__CORS__ALLOWED_ORIGINS" = "*.${prefs.mainDomain}";
            # Not working for now. See https://github.com/rs/cors/pull/120
            "SFTPGO_WEBDAVD__CORS__ALLOWED_METHODS" = "*";
            "SFTPGO_COMMON__PROXY_PROTOCOL" = "1";
            # This is in the container world. It is presumably safe to do this.
            "SFTPGO_COMMON__PROXY_ALLOWED" = "0.0.0.0/0";
          };
          traefikForwardingPort = 8080;
        } // mkContainer "filestash" prefs.ociContainers.enableFilestash {
          environment = {
            APPLICATION_URL = prefs.getFullDomainName "filestash";
          };
          volumes = [ "/var/data/filestash:/app/data/state" ];
          traefikForwardingPort = 8334;
        } // mkContainer "vault" prefs.ociContainers.enableVault {
          extraOptions = [ "--cap-add=IPC_LOCK" ];
          cmd = [ "server" ];
          environment = {
            VAULT_API_ADDR = "https://${prefs.getFullDomainName "vault"}";
          };
          volumes = [
            "/var/data/vault/config:/vault/config"
            "/var/data/vault/logs:/vault/logs"
            "/var/data/vault/file:/vault/file"
          ];
          environmentFiles = [ "/run/secrets/vault-env" ];
          traefikForwardingPort = 8200;
        } // mkContainer "homer" prefs.ociContainers.enableHomer {
          volumes = [ "/var/data/homer:/www/assets" ];
          traefikForwardingPort = 8080;
          extraOptions = let
            config = toYAML "homer-config" {
              subtitle = "Home";
              title = "Dashboard";
              theme = "default";
              colors = {
                dark = {
                  background = "#131313";
                  card-background = "#2b2b2b";
                  card-shadow = "rgba(0, 0, 0, 0.4)";
                  highlight-hover = "#5a95f5";
                  highlight-primary = "#3367d6";
                  highlight-secondary = "#4285f4";
                  link-hover = "#ffdd57";
                  text = "#eaeaea";
                  text-header = "#ffffff";
                  text-subtitle = "#f5f5f5";
                  text-title = "#fafafa";
                };
                light = {
                  background = "#f5f5f5";
                  card-background = "#ffffff";
                  card-shadow = "rgba(0, 0, 0, 0.1)";
                  highlight-hover = "#5a95f5";
                  highlight-primary = "#3367d6";
                  highlight-secondary = "#4285f4";
                  link-hover = "#363636";
                  text = "#363636";
                  text-header = "#ffffff";
                  text-subtitle = "#424242";
                  text-title = "#303030";
                };
              };
              footer = false;
              header = false;
              icon = "fas fa-skull-crossbones";
              links = [ ];
              services = [{
                name = "Applications";
                icon = "fas fa-cloud";
                items =
                  builtins.map (attrs: builtins.removeAttrs attrs [ "enable" ])
                  (builtins.filter (x: x.enable or true) [
                    {
                      enable = prefs.ociContainers.enableFreeipa;
                      name = "freeipa";
                      subtitle = "account management";
                      tag = "auth";
                      url = "https://${prefs.getFullDomainName "freeipa"}";
                    }
                    {
                      enable = prefs.ociContainers.enableCloudBeaver;
                      name = "cloud beaver";
                      subtitle = "database management";
                      tag = "database";
                      url = "https://${prefs.getFullDomainName "cloudbeaver"}";
                    }
                    {
                      enable = prefs.ociContainers.enableAuthelia;
                      name = "authelia";
                      subtitle = "authentication and authorization";
                      tag = "auth";
                      url = "https://${prefs.getFullDomainName "authelia"}";
                    }
                    {
                      enable = prefs.ociContainers.enableHledger;
                      name = "hledger";
                      subtitle = "online ledger";
                      tag = "house-keeping";
                      url = "https://${prefs.getFullDomainName "hledger"}";
                    }
                    {
                      enable = prefs.enableSmosServer;
                      name = "smos";
                      subtitle = "self-management";
                      tag = "productivity";
                      url = "https://${prefs.getFullDomainName "smos"}";
                    }
                    {
                      enable = prefs.enableWstunnel;
                      name = "wstunnel";
                      subtitle = "websocket tunnel";
                      tag = "network";
                      url = "https://${prefs.getFullDomainName "wstunnel"}";
                    }
                    {
                      enable = prefs.ociContainers.enableSearx;
                      name = "searx";
                      subtitle = "search engine";
                      tag = "search";
                      url = "https://${prefs.getFullDomainName "searx"}";
                    }
                    {
                      enable = prefs.ociContainers.enableRssBridge;
                      name = "rss-bridge";
                      subtitle = "rss feeds generator";
                      tag = "reading";
                      url = "https://${prefs.getFullDomainName "rss-bridge"}";
                    }
                    {
                      enable = prefs.ociContainers.enableWallabag;
                      name = "wallabag";
                      subtitle = "read it later";
                      tag = "reading";
                      url = "https://${prefs.getFullDomainName "wallabag"}";
                    }
                    {
                      enable = prefs.ociContainers.enableCodeServer
                        || prefs.enableCodeServer;
                      name = "code server";
                      subtitle = "text editing";
                      tag = "coding";
                      url = "https://${prefs.getFullDomainName "codeserver"}";
                    }
                    {
                      enable = prefs.enableSyncthing;
                      name = "syncthing";
                      subtitle = "file synchronization";
                      tag = "synchronization";
                      url = "https://${prefs.getFullDomainName "syncthing"}";
                    }
                    {
                      enable = prefs.enableGrafana;
                      name = "grafana";
                      subtitle = "monitoring dashboard";
                      tag = "operation";
                      url = "https://${prefs.getFullDomainName "grafana"}";
                    }
                    {
                      enable = prefs.ociContainers.enableRecipes;
                      name = "recipes";
                      subtitle = "cooking recipes";
                      tag = "house-keeping";
                      url = "https://${prefs.getFullDomainName "recipes"}";
                    }
                    {
                      enable = prefs.ociContainers.enableWger;
                      name = "wger";
                      subtitle = "fitness tracking";
                      tag = "fitness";
                      url = "https://${prefs.getFullDomainName "wger"}";
                    }
                    {
                      enable = prefs.ociContainers.enableEtesync;
                      name = "etesync";
                      subtitle = "contacts, calandar and tasks";
                      tag = "productivity";
                      url = "https://${prefs.getFullDomainName "etesync-pim"}";
                    }
                    {
                      enable = prefs.ociContainers.enableEtesyncDav;
                      name = "etesync dav";
                      subtitle = "etesync dav bridge";
                      tag = "productivity";
                      url = "https://${prefs.getFullDomainName "etesync-dav"}";
                    }
                    {
                      enable = prefs.ociContainers.enableEtesync;
                      name = "etesync notes";
                      subtitle = "note-taking";
                      tag = "productivity";
                      url =
                        "https://${prefs.getFullDomainName "etesync-notes"}";
                    }
                    {
                      enable = prefs.ociContainers.enableN8n;
                      name = "n8n";
                      subtitle = "workflow automation";
                      tag = "productivity";
                      url = "https://${prefs.getFullDomainName "n8n"}";
                    }
                    {
                      enable = prefs.ociContainers.enableGitea;
                      name = "gitea";
                      subtitle = "version control";
                      tag = "productivity";
                      url = "https://${prefs.getFullDomainName "gitea"}";
                    }
                    {
                      enable = prefs.ociContainers.enableWikijs;
                      name = "wikijs";
                      subtitle = "personal wiki";
                      tag = "documentation";
                      url = "https://${prefs.getFullDomainName "wikijs"}";
                    }
                    {
                      enable = prefs.ociContainers.enableXwiki;
                      name = "xwiki";
                      subtitle = "personal wiki";
                      tag = "documentation";
                      url = "https://${prefs.getFullDomainName "xwiki"}";
                    }
                    {
                      enable = prefs.ociContainers.enableHuginn;
                      name = "huginn";
                      subtitle = "automation agents";
                      tag = "automation";
                      url = "https://${prefs.getFullDomainName "huginn"}";
                    }
                    {
                      enable = prefs.ociContainers.enableTiddlyWiki;
                      name = "tiddlywiki";
                      subtitle = "personal wiki";
                      tag = "documentation";
                      url = "https://${prefs.getFullDomainName "tiddlywiki"}";
                    }
                    {
                      enable = prefs.ociContainers.enableGrocy;
                      name = "grocy";
                      subtitle = "ERP for household";
                      tag = "house-keeping";
                      url = "https://${prefs.getFullDomainName "grocy"}";
                    }
                    {
                      enable = prefs.ociContainers.enableCalibreWeb;
                      name = "calibre";
                      subtitle = "digital books";
                      tag = "reading";
                      url = "https://${prefs.getFullDomainName "calibre"}";
                    }
                    {
                      enable = prefs.ociContainers.enableDokuwiki;
                      name = "dokuwiki";
                      subtitle = "personal wiki";
                      tag = "productivity";
                      url = "https://${prefs.getFullDomainName "dokuwiki"}";
                    }
                    {
                      enable = prefs.ociContainers.enableTrilium;
                      name = "trilium";
                      subtitle = "note-taking";
                      tag = "productivity";
                      url = "https://${prefs.getFullDomainName "trilium"}";
                    }
                    {
                      name = "traefik";
                      subtitle = "traefik dashboard";
                      tag = "operations";
                      url = "https://${prefs.getFullDomainName "traefik"}";
                    }
                    {
                      enable = prefs.ociContainers.enableVaultwarden;
                      name = "vaultwarden";
                      subtitle = "password management";
                      tag = "security";
                      url = "https://${prefs.getFullDomainName "vaultwarden"}";
                    }
                    {
                      enable = prefs.ociContainers.enableVault;
                      name = "vault";
                      subtitle = "secrets management";
                      tag = "security";
                      url = "https://${prefs.getFullDomainName "vault"}";
                    }
                    {
                      enable = prefs.ociContainers.enablePleroma;
                      name = "pleroma";
                      subtitle = "microblogging";
                      tag = "social";
                      url = "https://${prefs.getFullDomainName "pleroma"}";
                    }
                    {
                      enable = prefs.ociContainers.enableJoplin;
                      name = "joplin";
                      subtitle = "note-taking";
                      tag = "productivity";
                      url = "https://${prefs.getFullDomainName "joplin"}";
                    }
                    {
                      enable = prefs.ociContainers.enableMiniflux;
                      name = "miniflux";
                      subtitle = "rss reader";
                      tag = "reading";
                      url = "https://${prefs.getFullDomainName "miniflux"}";
                    }
                    {
                      enable = prefs.ociContainers.enableNextcloud;
                      name = "nextcloud";
                      subtitle = "file synchronization";
                      tag = "synchronization";
                      url = "https://${prefs.getFullDomainName "nextcloud"}";
                    }
                    {
                      enable = prefs.ociContainers.enableSftpgo;
                      name = "sftpgo";
                      subtitle = "file synchronization";
                      tag = "synchronization";
                      url = "https://${prefs.getFullDomainName "sftpgo"}";
                    }
                    {
                      enable = prefs.ociContainers.enableSftpgo;
                      name = "webdav";
                      subtitle = "file synchronization";
                      tag = "synchronization";
                      url = "https://${prefs.getFullDomainName "webdav"}";
                    }
                    {
                      enable = prefs.ociContainers.enableFilestash;
                      name = "filestash";
                      subtitle = "file manager";
                      tag = "productivity";
                      url = "https://${prefs.getFullDomainName "filestash"}";
                    }
                    {
                      name = "keeweb";
                      enable = prefs.ociContainers.enableKeeweb;
                      subtitle = "password management";
                      tag = "security";
                      url = "https://${prefs.getFullDomainName "keeweb"}";
                    }
                    {
                      name = "clash";
                      subtitle = "clash instance management";
                      tag = "network";
                      url = "https://${prefs.getFullDomainName "clash"}";
                    }
                    {
                      name = "aria2";
                      subtitle = "download management";
                      tag = "network";
                      url = "https://${prefs.getFullDomainName "aria2"}";
                    }
                    {
                      name = "activitywatch";
                      enable = prefs.enableActivityWatch;
                      subtitle = "device usage monitor";
                      tag = "productivity";
                      url =
                        "https://${prefs.getFullDomainName "activitywatch"}";
                    }
                    {
                      enable = prefs.enableTtyd;
                      name = "ttyd";
                      subtitle = "web terminal emulator";
                      tag = "coding";
                      url = "https://${prefs.getFullDomainName "ttyd"}";
                    }
                    {
                      name = "organice";
                      subtitle = "org-mode files editing";
                      tag = "productivity";
                      url = "https://${prefs.getFullDomainName "organice"}";
                    }
                  ]);
              }];
            };
          in [
            "--mount=type=bind,source=${config},target=/www/assets/config.yml"
            "--label=domainprefix=home"
          ];
        } // mkContainer "etesync" prefs.ociContainers.enableEtesync {
          volumes = [ "/var/data/etesync:/data" ];
          dependsOn = [ "postgresql" ];
          environmentFiles = [ "/run/secrets/etesync-env" ];
          traefikForwardingPort = 3735;
        } // mkContainer "etesync-dav" prefs.ociContainers.enableEtesyncDav {
          volumes = [ "/var/data/etesync-dav:/data" ];
          traefikForwardingPort = 37358;
          environment = {
            "ETESYNC_URL" = "https://${prefs.getFullDomainName "etesync"}";
          };
        } // mkContainer "keeweb" prefs.ociContainers.enableKeeweb {
          volumes = [
            "${prefs.syncFolder}/private/keepass:/var/www/keeweb-local-server/databases"
          ];
          environmentFiles = [ "/run/secrets/keeweb-env" ];
          traefikForwardingPort = 8080;
        } // mkContainer "codeserver" prefs.ociContainers.enableCodeServer {
          volumes = [
            "${prefs.home}:/home/coder"
            # "${prefs.home}/Workspace:/home/coder/Workspace"
            # "${prefs.home}/.vscode:/home/coder/.vscode"
          ];
          middlewares = [ "authelia" ];
          extraOptions = [
            "--user=${builtins.toString prefs.ownerUid}:${
              builtins.toString prefs.ownerGroupGid
            }"
          ];
          environment = { "DOCKER_USER" = "${prefs.owner}"; };
          cmd = [
            "--disable-telemetry"
            "--user-data-dir=/home/coder/.vscode"
            "--auth=none"
          ];
          traefikForwardingPort = 8080;
        };
    };
  };

  # powerManagement = {
  #   enable = true;
  #   cpuFreqGovernor = "ondemand";
  # };

  systemd = let
    notify-systemd-unit-failures = let name = "notify-systemd-unit-failures";
    in {
      "${name}@" = {
        description = "notify systemd unit failures with mailutils";
        serviceConfig = {
          Type = "oneshot";
          ExecStart = ''
            ${pkgs.bash}/bin/bash -c "${pkgs.mailutils}/bin/mail --set=noASKCC --subject 'Systemd unit %i failed' ${prefs.owner} < /dev/null"
          '';
        };
      };
    };
  in (builtins.foldl' (a: e: pkgs.lib.recursiveUpdate a e) { } [
    {
      extraConfig = "DefaultTimeoutStopSec=10s";
      tmpfiles = {
        rules = [
          "d /root/.cache/trash - root root 30d"
          "d /root/.local/share/Trash - root root 30d"
          "d ${prefs.home}/.cache/trash - ${prefs.owner} ${prefs.ownerGroup} 30d"
          "d ${prefs.home}/.local/share/Trash - ${prefs.owner} ${prefs.ownerGroup} 30d"
        ] ++ [
          # Otherwise the parent directory's owner is root.
          # https://stackoverflow.com/questions/66362660/docker-volume-mount-giving-root-ownership-of-parent-directory
          "d ${prefs.nextcloudContainerDataDirectory} - 33 33 -"
          "f ${prefs.nextcloudContainerDataDirectory}/.ocdata - 33 33 -"
          "d ${prefs.nextcloudContainerDataDirectory}/e - 33 33 -"
        ] ++ pkgs.lib.optionals prefs.ociContainers.enableSftpgo [
          "d /var/data/sftpgo - ${prefs.owner} ${prefs.ownerGroup} -"
          "d /var/data/sftpgo/backups - ${prefs.owner} ${prefs.ownerGroup} -"
          "d /var/data/sftpgo/config - ${prefs.owner} ${prefs.ownerGroup} -"
          "d /var/data/sftpgo/data - ${prefs.owner} ${prefs.ownerGroup} -"
        ] ++ pkgs.lib.optionals prefs.ociContainers.enableEtesync [
          "d /var/data/etesync - 373 373 -"
          "d /var/data/etesync/media - 373 373 -"
        ] ++ pkgs.lib.optionals prefs.ociContainers.enableEtesyncDav
          [ "d /var/data/etesync-dav - 1000 1000 -" ]
          ++ pkgs.lib.optionals prefs.ociContainers.enableTrilium
          [ "d /var/data/trilium - 1000 1000 -" ]
          ++ pkgs.lib.optionals prefs.ociContainers.enableTiddlyWiki
          [ "d /var/data/tiddlywiki - ${prefs.owner} ${prefs.ownerGroup} -" ]
          ++ pkgs.lib.optionals prefs.ociContainers.enablePleroma
          [ "d /var/data/pleroma - 100 0 -" ]
          ++ pkgs.lib.optionals prefs.ociContainers.enableFilestash
          [ "d /var/data/filestash - 1000 1000 -" ]
          ++ pkgs.lib.optionals prefs.ociContainers.enableGitea [
            "d /var/data/gitea - ${prefs.owner} ${prefs.ownerGroup} -"
            "d /var/data/gitea/gitea - ${prefs.owner} ${prefs.ownerGroup} -"
          ];
      };
    }

    {
      services = notify-systemd-unit-failures // {
        init-oci-container-network = {
          description = "Create oci container networks";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig.Type = "oneshot";
          script = let
            dockercli = "${config.virtualisation.docker.package}/bin/docker";
            podmancli = "${config.virtualisation.podman.package}/bin/docker";
            cli = if prefs.ociContainerBackend == "docker" then
              dockercli
            else
              podmancli;
          in ''
            set -e
            if ! ${cli} network inspect ${prefs.ociContainerNetwork}; then
                if ! ${cli} network create ${prefs.ociContainerNetwork}; then
                    echo "creating network failed"
                fi
            fi
          '';
        };

        vault-ssh-ca-setup = let
          vault-server-init-script =
            pkgs.writeShellScript "vault-ssh-ca-setup-server" ''
              vault secrets enable -path=ssh-host-signer ssh
              vault write ssh-host-signer/config/ca generate_signing_key=true
              vault secrets enable -path=ssh-client-signer ssh
              vault write ssh-client-signer/config/ca generate_signing_key=true
                          '';
          vault-host-init-script =
            pkgs.writeShellScript "vault-ssh-ca-setup-host" ''
              vault write ssh-host-signer/roles/ssh-host key_type=ca ttl=87600h allow_host_certificates=true allowed_domains="localdomain,example.com" allow_subdomains=true algorithm_signer=rsa-sha2-512
              vault secrets tune -max-lease-ttl=87600h ssh-host-signer
              vault policy write ssh-host -<<"EOH"
              path "ssh-host-signer/sign/ssh-host" {  capabilities = [ "create", "update" ]}
              path "ssh-client-signer/config/ca" {  capabilities = [ "read" ]}
              EOH
              vault write auth/approle/role/ssh-host policies="ssh-host" token_ttl=1h token_max_ttl=4h
              VAULT_HOST_ROLE_ID=$(vault read -format=json auth/approle/role/ssh-host/role-id | jq -r ".data.role_id") VAULT_HOST_SECRET_ID=$(vault write -f -format=json auth/approle/role/ssh-host/secret-id | jq -r ".data.secret_id")
              VAULT_HOST_TOKEN="$(vault write -format json auth/approle/login role_id=$VAULT_HOST_ROLE_ID secret_id=$VAULT_HOST_SECRET_ID | jq -r ".auth.client_token")"
              VAULT_TOKEN=$VAULT_HOST_TOKEN vault write -field=signed_key ssh-host-signer/sign/ssh-host cert_type=host public_key=@/etc/ssh/ssh_host_ed25519_key.pub | tee /etc/ssh/ssh_host_ed25519_key-cert.pub
                          '';
          vault-client-init-script =
            pkgs.writeShellScript "vault-ssh-ca-setup-client" ''
              # Only root user is allowed to connect.
              # https://github.com/hashicorp/vault/blob/6da5bce9a0078a2e0856e365cb4dd350b77af6cb/website/content/docs/secrets/ssh/signed-ssh-certificates.mdx#name-is-not-a-listed-principal
              vault write ssh-client-signer/roles/ssh-root-user -<<"EOH"
              {
                "allow_user_certificates": true,
                "allowed_users": "*",
                "allowed_extensions": "permit-pty,permit-port-forwarding",
                "default_extensions": [
                  {
                    "permit-pty": ""
                  }
                ],
                "key_type": "ca",
                "default_user": "root",
                "algorithm_signer": "rsa-sha2-512",
                "ttl": "30m0s"
              }
              EOH
              vault policy write ssh-root-user -<<"EOH"
              path "ssh-client-signer/sign/ssh-root-user" {  capabilities = ["create", "update"]}
              path "ssh-client-signer/config/ca" {  capabilities = [ "read" ]}
              path "ssh-host-signer/config/ca" {  capabilities = [ "read" ]}
              EOH
              vault write auth/approle/role/ssh-root-user policies="ssh-root-user" token_ttl=6h token_max_ttl=12h
              VAULT_ROOT_USER_ROLE_ID=$(vault read -format=json auth/approle/role/ssh-root-user/role-id | jq -r ".data.role_id") VAULT_ROOT_USER_SECRET_ID=$(vault write -f -format=json auth/approle/role/ssh-root-user/secret-id | jq -r ".data.secret_id")
              VAULT_ROOT_USER_TOKEN="$(vault write -format json auth/approle/login role_id=$VAULT_ROOT_USER_ROLE_ID secret_id=$VAULT_ROOT_USER_SECRET_ID | jq -r ".auth.client_token")"
              ssh-keygen -f id_ed25519 -t ed25519 -P ""
              VAULT_TOKEN=$VAULT_ROOT_USER_TOKEN vault write -field=signed_key ssh-client-signer/sign/ssh-root-user public_key=@id_ed25519.pub | tee id_ed25519-cert.pub
              echo "@cert-authority * $(VAULT_TOKEN=$VAULT_ROOT_USER_TOKEN vault read -field=public_key ssh-host-signer/config/ca)" | tee -a ~/.ssh/known_hosts
                          '';
        in {
          enable = true;
          description = "Setup Vault CA Certificate";
          after = [ "network.target" ];
          path = [ pkgs.vault pkgs.jq pkgs.file pkgs.glibc ];
          script = ''
            set -euo pipefail
            # see ${vault-server-init-script} for some vault server setup instructions
            # see ${vault-host-init-script} for some vault host setup instructions
            # see ${vault-client-init-script} for some vault client setup instructions
            export VAULT_TOKEN="$(vault write -format json auth/approle/login role_id="$VAULT_ROLE_ID" secret_id="$VAULT_SECRET_ID" | jq -r ".auth.client_token")"
            if ca="$(vault read -field=public_key ssh-client-signer/config/ca)" && [[ -n "$ca" ]] ; then
                echo "$ca" > /etc/ssh/trusted-user-ca-keys.pem
            else
                exit 1
            fi
            if signed_key="$(vault write -field=signed_key ssh-host-signer/sign/ssh-host cert_type=host public_key=@/etc/ssh/ssh_host_ed25519_key.pub)" && [[ -n "$signed_key" ]]; then
                echo "$signed_key" > /etc/ssh/ssh_host_ed25519_key-cert.pub
            else
                exit 1
            fi
            cat > /etc/ssh/sshd_config_vault <<EOF
            TrustedUserCAKeys /etc/ssh/trusted-user-ca-keys.pem
            HostKey /etc/ssh/ssh_host_ed25519_key
            HostCertificate /etc/ssh/ssh_host_ed25519_key-cert.pub
            EOF
          '';
          serviceConfig = {
            Type = "simple";
            EnvironmentFile = "/run/secrets/vault-ssh-ca-setup-env";
          };
        };

        local-transparent-proxy-setup = {
          enable = true;
          description =
            "Setup route table and route rule for local transparent proxy";
          after = [ "network.target" ];
          path = [ pkgs.iproute pkgs.procps pkgs.iptables ];

          # TODO: Dont't know why `ip route show table 100` results will disappear.
          # The error of `ip route show table 100` is
          # Error: ipv4: FIB table does not exist.
          # Dump terminatedp
          # Sleeping is dirty, but it seems to be working.
          script = ''
            set -xu
            set +e
            sysctl -w net.ipv4.conf.default.route_localnet=1
            sysctl -w net.ipv4.conf.all.route_localnet=1
            for i in $(seq 1 30); do
                ip route show table 100
                if [[ -z "$(ip rule list from 127.0.0.1/8 iif lo table 100)" ]]; then
                    ip rule add from 127.0.0.1/8 iif lo table 100;
                fi
                ip route replace local 0.0.0.0/0 dev lo table 100
                ip route show table 100
                sleep 10
            done
          '';
          serviceConfig = {
            Type = "oneshot";
            Environment = "TMP_FILE=%T/%n";
          };
        };
      } // lib.optionalAttrs prefs.enableWstunnel {
        # Copied from https://github.com/hmenke/nixos-modules/blob/da7bf05fd771373a8528dd00b97480c38d94c6de/modules/wstunnel/module.nix
        "wstunnel" = {
          description = "wstunnel server";
          before = let
            wg-quick = map (iface: "wg-quick-${iface}.service")
              (lib.attrNames config.networking.wg-quick.interfaces);
            wireguard = lib.optionals config.networking.wireguard.enable
              (map (iface: "wireguard-${iface}.service")
                (lib.attrNames config.networking.wireguard.interfaces));
          in wg-quick ++ wireguard;
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          path = [ pkgs.wstunnel ];
          serviceConfig = {
            Restart = "always";
            RestartSec = "1s";
            # User
            DynamicUser = true;
            # Capabilities
            AmbientCapabilities = [ "CAP_NET_RAW" "CAP_NET_BIND_SERVICE" ];
            CapabilityBoundingSet = [ "CAP_NET_RAW" "CAP_NET_BIND_SERVICE" ];
            # Security
            NoNewPrivileges = true;
            # Sandboxing
            ProtectSystem = "strict";
            ProtectHome = lib.mkDefault true;
            PrivateTmp = true;
            PrivateDevices = true;
            ProtectHostname = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;
            RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
            RestrictNamespaces = true;
            LockPersonality = true;
            MemoryDenyWriteExecute = true;
            RestrictRealtime = true;
            RestrictSUIDSGID = true;
            RemoveIPC = true;
            PrivateMounts = true;
            # System Call Filtering
            SystemCallArchitectures = "native";
          };
          script = ''
            exec wstunnel --verbose --server 127.0.0.1:${
              builtins.toString prefs.wstunnelPort
            }
          '';
        };
      } // pkgs.lib.optionalAttrs
        (prefs.buildZerotierone && !prefs.enableZerotierone) {
          # build zero tier one anyway, but enable it on prefs.enableZerotierone is true;
          "zerotierone" = { wantedBy = lib.mkForce [ ]; };
        } // pkgs.lib.optionalAttrs (config.virtualisation.docker.enable) {
          "docker" = {
            serviceConfig = {
              ExecStartPost = [
                "${pkgs.procps}/bin/sysctl net.bridge.bridge-nf-call-iptables=0 net.bridge.bridge-nf-call-ip6tables=0 net.bridge.bridge-nf-call-arptables=0"
              ];
            };
          };
        } // pkgs.lib.optionalAttrs (prefs.enableK3s) {
          "k3s" = let
            k3sPatchScript = pkgs.writeShellScript "add-k3s-config" ''
              ${pkgs.k3s}/bin/k3s kubectl patch -n kube-system services traefik -p '{"spec":{"ports":[{"name":"http","nodePort":30080,"port":30080,"protocol":"TCP","targetPort":"http"},{"name":"https","nodePort":30443,"port":30443,"protocol":"TCP","targetPort":"https"},{"$patch":"replace"}]}}' || ${pkgs.coreutils}/bin/true
              ${pkgs.coreutils}/bin/chown ${prefs.owner} /etc/rancher/k3s/k3s.yaml || ${pkgs.coreutils}/bin/true
            '';
          in {
            path = if prefs.enableZfs then [ pkgs.zfs ] else [ ];
            serviceConfig = {
              ExecStartPost = [
                "${k3sPatchScript}"
                "${pkgs.procps}/bin/sysctl net.bridge.bridge-nf-call-iptables=0 net.bridge.bridge-nf-call-ip6tables=0 net.bridge.bridge-nf-call-arptables=0"
              ];
            };
          };
        } // pkgs.lib.optionalAttrs (prefs.enableCrio) {
          "crio" = {
            path = with pkgs;
              [ conntrack-tools ] ++ (lib.optionals prefs.enableZfs [ zfs ]);
          };
        } // pkgs.lib.optionalAttrs (prefs.enableJupyter) {
          "jupyterhub" = { path = with pkgs; [ nodejs_latest ]; };
        } // pkgs.lib.optionalAttrs (prefs.enableAria2) {
          "aria2" = {
            serviceConfig = {
              Environment = "ARIA2_RPC_SECRET=token_nekot";
              EnvironmentFile = "/run/secrets/aria2-env";
            };
          };
        } // pkgs.lib.optionalAttrs (prefs.enablePromtail) {
          "promtail" = {
            serviceConfig = { EnvironmentFile = "/run/secrets/promtail-env"; };
          };
        } // pkgs.lib.optionalAttrs (prefs.enableGrafana) {
          "grafana" = {
            serviceConfig = { EnvironmentFile = "/run/secrets/grafana-env"; };
          };
        } // pkgs.lib.optionalAttrs (prefs.enableResolved) {
          "systemd-resolved" = {
            serviceConfig = { Environment = "SYSTEMD_LOG_LEVEL=debug"; };
          };
        } // pkgs.lib.optionalAttrs (prefs.ociContainers.enableWallabag) {
          "${prefs.ociContainerBackend}-wallabag" = {
            postStart = ''
              set -xe
              # https://github.com/moby/moby/issues/41890
              export HOME=/root
              retries=0
              while ! ${prefs.ociContainerBackend} exec wallabag /entrypoint.sh migrate; do
                  if (( retries > 10 )); then
                      echo "Giving up on initializing postgresql database."
                      exit 0
                  else
                      retries=$(( retries + 1 ))
                      sleep 2
                  fi
              done
            '';
          };
        } // pkgs.lib.optionalAttrs (prefs.enablePostgresql) {
          "postgresql" = { serviceConfig = { SupplementaryGroups = "keys"; }; };
        } // pkgs.lib.optionalAttrs (prefs.enableTraefik) {
          "traefik" = {
            serviceConfig = {
              LogsDirectory = "traefik";
              EnvironmentFile = "/run/secrets/traefik-env";
              SupplementaryGroups = "keys acme";
            } // (lib.optionalAttrs (prefs.ociContainerBackend == "docker") {
              SupplementaryGroups = "keys acme docker";
            }) // (lib.optionalAttrs (prefs.ociContainerBackend == "podman") {
              User = lib.mkForce "root";
            }) // (lib.optionalAttrs (prefs.enableK3s) {
              # TODO: Use a less privileged kube config.
              Environment = "KUBECONFIG=/kubeconfig.yaml";
              ExecStartPre =
                "+${pkgs.acl}/bin/setfacl -m 'u:traefik:r--' /kubeconfig.yaml";
              BindPaths = "/etc/rancher/k3s/k3s.yaml:/kubeconfig.yaml";
            });
          };
        } // pkgs.lib.optionalAttrs (prefs.enableCodeServer) {
          "code-server" = {
            enable = true;
            description = "Remote VSCode Server";
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            path = [ pkgs.go pkgs.git pkgs.direnv ];
            serviceConfig = {
              Type = "simple";
              ExecStart =
                "${pkgs.code-server}/bin/code-server --disable-telemetry --disable-update-check --user-data-dir ${prefs.home}/.vscode --extensions-dir ${prefs.home}/.vscode/extensions --home https://${prefs.domain} --bind-addr 127.0.0.1:4050 --auth password";
              EnvironmentFile = "/run/secrets/code-server-env";
              WorkingDirectory = prefs.home;
              NoNewPrivileges = true;
              User = prefs.owner;
              Group = prefs.ownerGroup;
            };
          };
        } // pkgs.lib.optionalAttrs
        (prefs.enableAioproxy && ((pkgs.myPackages.aioproxy or null) != null)) {
          "aioproxy" = {
            enable = true;
            description = "All-in-one Reverse Proxy";
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = {
              Type = "simple";
              ExecStart =
                "${pkgs.myPackages.aioproxy}/bin/aioproxy -v 2 -l 0.0.0.0:${
                  builtins.toString prefs.aioproxyPort
                } -u 127.0.0.1:8000 -p both -ssh 127.0.0.1:22 -eternal-terminal 127.0.0.1:2022 -http 127.0.0.1:8080 -tls 127.0.0.1:30443";
              ExecStartPost = [
                "-${pkgs.systemd}/bin/systemctl start --no-block local-transparent-proxy-setup"
              ];
            };
          };
        };
    }

    (lib.foldAttrs (n: a: n ++ a) [ ] [
      # nextcloud container files owner
      # See also https://github.com/nextcloud/docker/pull/1278
      {
        automounts = [{
          enable = prefs.ociContainers.enableNextcloud;
          description = "Automount nextcloud container files directory.";
          where = prefs.ownerNextcloudContainerDataDirectory;
          wantedBy = [ "multi-user.target" ];
        }];
        mounts = [{
          enable = prefs.ociContainers.enableNextcloud;
          where = prefs.ownerNextcloudContainerDataDirectory;
          what = prefs.syncFolder;
          type = "fuse.bindfs";
          options = "map=${builtins.toString prefs.ownerUid}/33:@${
              builtins.toString prefs.ownerGroupGid
            }/@33";
          unitConfig = { RequiresMountsFor = prefs.syncFolder; };
        }];
      }
      # nextcloud
      {
        automounts = [{
          enable = prefs.enableNextcloud;
          description = "Automount nextcloud sync directory.";
          where = prefs.nextcloudWhere;
          wantedBy = [ "multi-user.target" ];
        }];
        mounts = [{
          enable = prefs.enableNextcloud;
          where = prefs.nextcloudWhere;
          what = prefs.nextcloudWhat;
          type = "davfs";
          options = "rw,uid=${builtins.toString prefs.ownerUid},gid=${
              builtins.toString prefs.ownerGroupGid
            }";
          wants = [ "network-online.target" ];
          wantedBy = [ "remote-fs.target" ];
          after = [ "network-online.target" ];
        }];
      }
      # yandex
      {
        automounts = [{
          enable = prefs.enableYandex;
          description = "Automount yandex sync directory.";
          where = prefs.yandexWhere;
          wantedBy = [ "multi-user.target" ];
        }];
        mounts = [{
          enable = prefs.enableYandex;
          where = prefs.yandexWhere;
          what = prefs.yandexWhat;
          type = "davfs";
          options = "rw,user=uid=${builtins.toString prefs.ownerUid},gid=${
              builtins.toString prefs.ownerGroupGid
            }";
          wants = [ "network-online.target" ];
          wantedBy = [ "remote-fs.target" ];
          after = [ "network-online.target" ];
        }];
      }
    ])

    # The following is not pure, disable it for now.
    # {
    #   packages = let
    #     usrLocalPrefix = "/usr/local/lib/systemd/system";
    #     etcPrefix = "/etc/systemd/system";
    #     makeUnit = from: to: unit:
    #       pkgs.writeTextFile {
    #         name = builtins.replaceStrings [ "@" ] [ "__" ] unit;
    #         text = builtins.readFile "${from}/${unit}";
    #         destination = "${to}/${unit}";
    #       };
    #     getAllUnits = from: to:
    #       let
    #         files = builtins.readDir from;
    #         units = pkgs.lib.attrNames
    #           (pkgs.lib.filterAttrs (n: v: v == "regular" || v == "symlink")
    #             files);
    #         newUnits = map (unit: makeUnit from to unit) units;
    #       in pkgs.lib.optionals (builtins.pathExists from) newUnits;
    #   in getAllUnits usrLocalPrefix etcPrefix;
    # }

    (let
      name = "clash-redir";
      updaterName = "${name}-config-updater";
      script = builtins.path {
        inherit name;
        path = prefs.getDotfile "dot_bin/executable_clash-redir";
      };
    in {
      services."${name}" = {
        description = "transparent proxy with clash";
        enable = prefs.enableClashRedir;
        wantedBy =
          if prefs.autoStartClashRedir then [ "default.target" ] else [ ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        path = [
          pkgs.coreutils
          pkgs.clash
          pkgs.curl
          pkgs.procps
          pkgs.libcap
          pkgs.iptables
          pkgs.iproute
          pkgs.bash
          pkgs.gawk
        ];
        serviceConfig = {
          Type = "forking";
          ExecStartPre = "${pkgs.writeShellScript "clash-redir-prestart" ''
            set -euxo pipefail
            mkdir -p /etc/clash-redir
            if ! [[ -e /etc/clash-redir/config.yaml ]]; then
                if ! [[ -e /etc/clash-redir/default.yaml ]]; then
                    systemctl restart ${updaterName}
                fi
                ln -sfn /etc/clash-redir/default.yaml /etc/clash-redir/config.yaml
            fi
          ''}";
          ExecStart = "${script} start";
          ExecStop = "${script} stop";
        };
      };
      services."${updaterName}" = let
        clash-config-update-script =
          pkgs.writeShellScript "clash-config-update-script" ''
            set -xeu
            CLASH_USER=clash
            CLASH_UID="$(id -u "$CLASH_USER")"
            CLASH_TEMP_CONFIG="''${TMPDIR:-/tmp}/clash-config-$(date -u +"%Y-%m-%dT%H:%M:%SZ").yaml"
            CLASH_CONFIG=/etc/clash-redir/default.yaml
            # We first try to download the config file on behave of "$CLASH_USER",
            # so that we can bypass the transparent proxy, which does nothing when programs are ran by "$CLASH_USER".
            if ! sudo -u "$CLASH_USER" curl "$CLASH_URL" -o "$CLASH_TEMP_CONFIG"; then
                if ! curl "$CLASH_URL" -o "$CLASH_TEMP_CONFIG"; then
                    >&2 echo "Failed to download clash config"
                    exit 1
                fi
            fi
            if diff "$CLASH_TEMP_CONFIG" "$CLASH_CONFIG"; then
                rm "$CLASH_TEMP_CONFIG"
                exit 0
            fi
            mv --backup=numbered "$CLASH_TEMP_CONFIG" "$CLASH_CONFIG"
            if ! curl -X PUT -H 'content-type: application/json' -d "{\"path\": \"$CLASH_CONFIG\"}" 'http://localhost:9090/configs/'; then
                if systemctl is-active --quiet ${name}; then
                    systemctl restart ${name}
                fi
            fi
          '';
      in {
        description = "update clash config";
        enable = prefs.enableClashRedir;
        wantedBy = [ "default.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        path = [
          pkgs.coreutils
          pkgs.systemd
          pkgs.sudo
          pkgs.curl
          pkgs.diffutils
          pkgs.libcap
          pkgs.utillinux
        ];
        serviceConfig = {
          Type = "oneshot";
          ExecStart = "${clash-config-update-script}";
          EnvironmentFile = "/run/secrets/clash-env";
          Restart = "on-failure";
        };
      };
      timers."${updaterName}" = {
        enable = prefs.enableClashRedir;
        wantedBy = [ "default.target" ];
        wants = [ "network-online.target" ];
        after = [ "network-online.target" ];
        onFailure = [ "notify-systemd-unit-failures@${updaterName}.service" ];
        timerConfig = {
          OnCalendar = "hourly";
          Unit = "${updaterName}.service";
          Persistent = true;
        };
      };
    })

    ({
      services = pkgs.lib.optionalAttrs prefs.ociContainers.enableHledger {
        "${prefs.ociContainerBackend}-hledger-init" = {
          serviceConfig = {
            Type = lib.mkForce "oneshot";
            Restart = lib.mkForce "on-failure";
          };
        };
      };
    })

    (let
      nextcloudUnitName = "${prefs.ociContainerBackend}-nextcloud";
      nextcloudMaintenanceUnitName = "${nextcloudUnitName}-maintenance";
    in {
      services = pkgs.lib.optionalAttrs prefs.ociContainers.enableNextcloud {
        "${nextcloudMaintenanceUnitName}" = let
          maintain-script = pkgs.writeShellScript "nextcloud-maintain-script" ''
            ${prefs.ociContainerBackend} exec --user 33 nextcloud ./occ files:scan e
          '';
        in {
          description = "Maintain ${prefs.ociContainerBackend} nextcloud";
          enable = true;
          wants = [ "network-online.target" "${nextcloudUnitName}.service" ];
          after = [ "network-online.target" "${nextcloudUnitName}.service" ];
          path =
            [ pkgs.coreutils pkgs.gzip pkgs.systemd pkgs.curl pkgs.utillinux ]
            ++ (lib.optionals (prefs.ociContainerBackend == "docker")
              [ config.virtualisation.docker.package ])
            ++ (lib.optionals (prefs.ociContainerBackend == "podman")
              [ config.virtualisation.podman.package ]);
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${maintain-script}";
            Restart = "on-failure";
          };
        };
      };
      timers = pkgs.lib.optionalAttrs prefs.ociContainers.enableNextcloud {
        "${nextcloudMaintenanceUnitName}" = {
          enable = true;
          wantedBy = [ "default.target" ];
          timerConfig = {
            OnCalendar = "hourly";
            RandomizedDelaySec = 10 * 60;
            Unit = "${nextcloudMaintenanceUnitName}.service";
            Persistent = true;
          };
        };
      };
    })

    (let
      postgresqlUnitName = "${prefs.ociContainerBackend}-postgresql";
      postgresqlInitUnitName = "${postgresqlUnitName}-init";
      postgresqlBackupUnitName = "${postgresqlUnitName}-backup";
    in {
      services = pkgs.lib.optionalAttrs prefs.ociContainers.enablePostgresql {
        "${postgresqlInitUnitName}" = {
          serviceConfig = { Restart = lib.mkForce "on-failure"; };
        };
        "${postgresqlBackupUnitName}" = let
          backup-script = pkgs.writeShellScript "postgresql-backup-script" ''
            set -xeu -o pipefail
            umask 0077
            mkdir -p "$BACKUP_DIR"
            export HOME=/root
            ${prefs.ociContainerBackend} exec -e PGHOST -e PGUSER -e PGPASSWORD postgresql pg_dumpall | gzip -c > "$BACKUP_DIR/all.tmp.sql.gz"
            if [ -e "$BACKUP_DIR/all.sql.gz" ]; then
                mv "$BACKUP_DIR/all.sql.gz" "$BACKUP_DIR/all.prev.sql.gz"
            fi
            mv $BACKUP_DIR/all.tmp.sql.gz $BACKUP_DIR/all.sql.gz
          '';
        in {
          description =
            "Backup ${prefs.ociContainerBackend} postgresql database";
          enable = true;
          wants = [ "network-online.target" "${postgresqlUnitName}.service" ];
          after = [ "network-online.target" "${postgresqlUnitName}.service" ];
          path =
            [ pkgs.coreutils pkgs.gzip pkgs.systemd pkgs.curl pkgs.utillinux ]
            ++ (lib.optionals (prefs.ociContainerBackend == "docker")
              [ config.virtualisation.docker.package ])
            ++ (lib.optionals (prefs.ociContainerBackend == "podman")
              [ config.virtualisation.podman.package ]);
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${backup-script}";
            EnvironmentFile = "/run/secrets/postgresql-backup-env";
            Restart = "on-failure";
          };
        };
      };
      timers = pkgs.lib.optionalAttrs prefs.ociContainers.enablePostgresql {
        "${postgresqlBackupUnitName}" = {
          enable = true;
          wantedBy = [ "default.target" ];
          onFailure = [
            "notify-systemd-unit-failures@${postgresqlBackupUnitName}.service"
          ];
          timerConfig = {
            OnCalendar = "daily";
            RandomizedDelaySec = 2 * 60 * 60;
            Unit = "${postgresqlBackupUnitName}.service";
            Persistent = true;
          };
        };
      };
    })
  ]) // {
    user = builtins.foldl' (a: e: pkgs.lib.recursiveUpdate a e) { } [
      { services = notify-systemd-unit-failures; }
      (let
        name = "ddns";
        unitName = "${name}@";
        script = pkgs.writeShellScript "ddns" ''
          set -eu
          host="''${DDNS_HOST:-$(hostname)}"
          if [[ -n "$1" ]] && [[ "$1" != "default" ]]; then host="$1"; fi
          base="$DDNS_BASE_DOMAIN"
          domain="$host.$base"
          password="$DDNS_PASSWORD"
          interfaces="$(ip link show up | awk -F'[ :]' '/MULTICAST/&&/LOWER_UP/ {print $3}')"
          ipAddr="$(parallel -k -r -v upnpc -m {1} -s ::: $interfaces 2>/dev/null | awk '/ExternalIPAddress/ {print $3}' | head -n1 || true)"
          if [[ -z "$ipAddr" ]]; then ipAddr="$(curl -s myip.ipip.net | perl -pe 's/.*?([0-9]{1,3}.*[0-9]{1,3}?).*/\1/g')"; fi
          curl "https://dyn.dns.he.net/nic/update?hostname=$domain&password=$password&myip=$ipAddr"
          ipv6Addr="$(ip -6 addr show scope global primary | grep -v mngtmpaddr | awk '/inet6/ {print $2}' | head -n1 | awk -F/ '{print $1}')"
          if [[ -n "$ipv6Addr" ]]; then curl "https://dyn.dns.he.net/nic/update?hostname=$domain&password=$password&myip=$ipv6Addr"; fi
        '';
      in {
        services.${unitName} = {
          description = "ddns worker";
          enable = prefs.enableDdns;
          wantedBy = [ "default.target" ];
          path = [
            pkgs.coreutils
            pkgs.inetutils
            pkgs.parallel
            pkgs.miniupnpc
            pkgs.iproute
            pkgs.gawk
            pkgs.perl
            pkgs.curl
          ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${script} %i";
            EnvironmentFile = "/run/secrets/ddns-env";
          };
        };
        timers.${unitName} = {
          enable = prefs.enableDdns;
          wantedBy = [ "default.target" ];
          onFailure = [ "notify-systemd-unit-failures@%i.service" ];
          timerConfig = {
            OnCalendar = "*-*-* *:2/10:43";
            Unit = "${unitName}%i.service";
            Persistent = true;
          };
        };
      })

      {
        services.nextcloud-client = {
          enable = prefs.enableNextcloudClient;
          description = "nextcloud client";
          wantedBy = [ "default.target" ];
          serviceConfig = {
            Restart = "always";
            EnvironmentFile = "%h/.config/Nextcloud/env";
          };
          path = [ pkgs.nextcloud-client pkgs.inotify-tools ];
          script = ''
            mkdir -p "$HOME/$localFolder"
            while true; do
                  nextcloudcmd --non-interactive --silent --user "$user" --password "$password" "$localFolder" "$remoteUrl" || true
                  inotifywait -t 120 "$localFolder" > /dev/null 2>&1 || true
            done
          '';
        };
      }

      (let
        name = "hole-puncher";
        unitName = "${name}@";
        script = pkgs.writeShellScript "hole-puncher" ''
          set -eu
          instance="44443-${
            builtins.toString
            (if prefs.enableAioproxy then prefs.aioproxyPort else 44443)
          }"
          if [[ -n "$1" ]] && grep -Eq '[0-9]+-[0-9]+' <<< "$1"; then instance="$1"; fi
          externalPort="$(awk -F- '{print $2}' <<< "$instance")"
          internalPort="$(awk -F- '{print $1}' <<< "$instance")"
          interfaces="$(ip link show up | awk -F'[ :]' '/MULTICAST/&&/LOWER_UP/ {print $3}' | grep -v veth)"
          ipAddresses="$(parallel -k ip addr show dev {1} ::: $interfaces | grep -Po 'inet \K[\d.]+')"
          protocols="tcp udp"
          result="$(parallel -r -v upnpc -m {1} -a {2} $internalPort $externalPort {3} ::: $interfaces :::+ $ipAddresses ::: $protocols || true)"
          awk -v OFS=, '/is redirected to/ {print $2, $8, $3}' <<< "$result"
        '';
      in {
        services.${unitName} = {
          description = "NAT traversal worker";
          enable = prefs.enableHolePuncher && prefs.enableSslh;
          wantedBy = [ "default.target" ];
          path = [
            pkgs.coreutils
            pkgs.parallel
            pkgs.miniupnpc
            pkgs.iproute
            pkgs.gawk
          ];
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${script} %i";
          };
        };
        timers.${unitName} = {
          enable = prefs.enableHolePuncher;
          wantedBy = [ "default.target" ];
          onFailure = [ "notify-systemd-unit-failures@%i.service" ];
          timerConfig = {
            OnCalendar = "*-*-* *:3/20:00";
            Unit = "${unitName}%i.service";
            Persistent = true;
          };
        };
      })
      (let name = "task-warrior-sync";
      in {
        services.${name} = {
          description = "sync task warrior tasks";
          enable = prefs.enableTaskWarriorSync;
          serviceConfig = {
            Type = "oneshot";
            ExecStart = "${pkgs.taskwarrior}/bin/task synchronize";
          };
        };
        timers.${name} = {
          enable = prefs.enableTaskWarriorSync;
          onFailure = [ "notify-systemd-unit-failures@%i.service" ];
          wantedBy = [ "default.target" ];
          timerConfig = {
            OnCalendar = "*-*-* *:1/3:00";
            Unit = "${name}.service";
            Persistent = true;
          };
        };
      })

      (let name = "vdirsyncer";
      in {
        services.${name} = {
          description = "vdirsyncer sync";
          enable = prefs.enableTaskWarriorSync;
          serviceConfig = {
            Type = "oneshot";
            # ExecStartPre = ''
            #   ${pkgs.bash}/bin/bash -c "${pkgs.coreutils}/bin/yes | ${pkgs.vdirsyncer}/bin/vdirsyncer discover"'';
            ExecStartPre = "${pkgs.vdirsyncer}/bin/vdirsyncer discover";
            ExecStart = "${pkgs.vdirsyncer}/bin/vdirsyncer sync";
          };
        };
        timers.${name} = {
          enable = prefs.enableVdirsyncer;
          onFailure = [ "notify-systemd-unit-failures@%i.service" ];
          wantedBy = [ "default.target" ];
          timerConfig = {
            OnCalendar = "*-*-* *:1/3:00";
            Unit = "${name}.service";
            Persistent = true;
          };
        };
      })

      (let name = "yandex-disk";
      in if prefs.enableYandexDisk then {
        services.${name} = {
          enable = true;
          description = "Yandex-disk server";
          onFailure = [ "notify-systemd-unit-failures@%i.service" ];
          wants = [ "network-online.target" ];
          after = [ "network-online.target" ];
          wantedBy = [ "default.target" ];
          unitConfig.RequiresMountsFor = prefs.syncFolder;
          serviceConfig = {
            Restart = "always";
            ExecStart =
              "${pkgs.yandex-disk}/bin/yandex-disk start --no-daemon --auth=/run/secrets/yandex-passwd --dir='${prefs.syncFolder}' ${
                lib.concatMapStringsSep " " (dir: "--exclude-dirs='${dir}'")
                prefs.yandexExcludedDirs
              }";
          };
        };
      } else
        { })
    ];
  };

  nix = {
    inherit (prefs) buildMachines buildCores maxJobs distributedBuilds;
    package = pkgs.nixFlakes;
    extraOptions =
      pkgs.lib.optionalString (config.nix.package == pkgs.nixFlakes)
      "experimental-features = nix-command flakes";
    binaryCaches =
      [ "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store" ];
    binaryCachePublicKeys = [ ];
    useSandbox = true;
    trustedUsers = [ "root" prefs.owner "@wheel" ];
    gc = {
      automatic = true;
      options = "--delete-older-than 60d";
    };
    optimise = { automatic = true; };
    autoOptimiseStore = true;
  };

  boot = {
    binfmt = { inherit (prefs) emulatedSystems; };
    inherit (prefs)
      kernelParams extraModulePackages kernelModules kernelPatches
      kernelPackages;
    kernel.sysctl = prefs.kernelSysctl;
    loader = {
      generationsDir = {
        enable = prefs.enableGenerationsDir;
        copyKernels = true;
      };
      efi = { canTouchEfiVariables = prefs.efiCanTouchEfiVariables; };
      grub = {
        enable = prefs.enableGrub;
        copyKernels = true;
        efiSupport = true;
        efiInstallAsRemovable = !prefs.efiCanTouchEfiVariables;
        enableCryptodisk = true;
        useOSProber = true;
        zfsSupport = prefs.enableZfs;
      };
      systemd-boot = {
        enable = prefs.enableSystemdBoot;
        configurationLimit = 25;
      };
      raspberryPi = {
        enable = prefs.enableRaspberryPiBoot;
        version = prefs.raspberryPiVersion;
      };
    };

    supportedFilesystems = if (prefs.enableZfs) then [ "zfs" ] else [ ];
    zfs = { enableUnstable = prefs.enableZfsUnstable; };
    crashDump = { enable = prefs.enableCrashDump; };
    initrd.network = {
      enable = true;
      ssh = let
        f = impure.sshAuthorizedKeys;
        authorizedKeys = pkgs.lib.optionals (builtins.pathExists f)
          (builtins.filter (x: x != "")
            (pkgs.lib.splitString "\n" (builtins.readFile f)));
        hostKeys =
          builtins.filter (x: builtins.pathExists x) impure.sshHostKeys;
      in {
        inherit (prefs) authorizedKeys hostKeys;
        enable = false && prefs.enableBootSSH && prefs.authorizedKeys != [ ]
          && prefs.hostKeys != [ ];
      };
    };
  };
}
