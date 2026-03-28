{
  config,
  pkgs,
  lib,
  options,
  inputs,
  ...
}@args:
let
  prefsAttr = import ./prefs.nix args;
  prefs = prefsAttr.all;
  stable = pkgs.stable;
  unstable = pkgs.unstable;
  impure = {
    mitmproxyCAFile = "${prefs.home}/.mitmproxy/mitmproxy-ca.pem";
    sslhConfigFile = "${prefs.home}/.config/sslh/sslh.conf";
    sshAuthorizedKeys = "${prefs.home}/.ssh/authorized_keys";
  };
  # YAML is a superset of JSON.
  toYAML = name: attrs: builtins.toFile "${name}.json" (builtins.toJSON attrs);

  # Helper to make merging a ton of optional feature more clear.
  mergeOptionalConfigs =
    list: builtins.foldl' (acc: e: acc // (lib.optionalAttrs e.enable e.config)) { } list;

  mergeOptionalLists =
    list: builtins.foldl' (acc: e: acc ++ (lib.optionals e.enable e.list)) [ ] list;

  # Copied from https://github.com/tejing1/nixos-config/blob/5c08d09dd785c569941021aedaa6ff80bc86be63/lib/sys/mkFlake.nix
  generateFlake =
    let
      inherit (builtins)
        mapAttrs
        concatMap
        attrValues
        toJSON
        listToAttrs
        ;
      inherit (pkgs) runCommand;
      inherit (lib) nameValuePair concatStrings mapAttrsToList;
      inherit (lib.strings) escapeNixIdentifier escapeNixString;

      cleanNode =
        flake:
        let
          spec = {
            type = "path";
            path = flake.outPath;
            inherit (flake) narHash;
          };
        in
        {
          # TODO: Any reliable way to differentiate flake and non-flake inputs?
          flake = flake ? inputs || flake ? outputs;
          inputs = mapAttrs (_: cleanNode) (flake.inputs or { });
          locked = spec;
          original = spec;
        };
      flattenNode =
        prefix: node:
        let
          ids = mapAttrs (n: v: (flattenNode (prefix + "-" + n) v).name) node.inputs;
          nod = concatMap (x: x) (
            attrValues (mapAttrs (n: v: (flattenNode (prefix + "-" + n) v).value) node.inputs)
          );
        in
        nameValuePair prefix ([ (nameValuePair prefix (node // { inputs = ids; })) ] ++ nod);

    in
    flakeInputs:
    let
      inputsCode = "{${
        concatStrings (
          mapAttrsToList (n: v: ''
            ${escapeNixIdentifier n}.url=${escapeNixString "path:${v.sourceInfo.outPath}?narHash=${v.sourceInfo.narHash}"};
          '') flakeInputs
        )
      }}";
      rootNode = {
        inputs = mapAttrs (_: cleanNode) flakeInputs;
      };
      lockJSON = toJSON {
        version = 7;
        root = "self";
        nodes = listToAttrs (flattenNode "self" rootNode).value;
      };

    in
    outputsCode:

    runCommand "source" { } ''
      mkdir -p $out
      cat <<"EOF" >$out/flake.nix
      {inputs=${inputsCode};outputs=${outputsCode};}
      EOF
      cat <<"EOF" >$out/default.nix
      (import (fetchTarball {
        url =
          "https://github.com/edolstra/flake-compat/archive/99f1c2157fba4bfe6211a321fd0ee43199025dbf.tar.gz";
        sha256 = "0x2jn3vrawwv9xp15674wjz9pixwjyj3j771izayl962zziivbx2";
      }) { src = ./.; }).defaultNix.legacyPackages.${config.nixpkgs.system}
      EOF
      cat <<"EOF" >$out/flake.lock
      ${lockJSON}
      EOF
    '';

  nvidiaEnabled =
    lib.elem "nvidia" config.services.xserver.videoDrivers && config.hardware.nvidia.modesetting.enable;
in
{
  passthru = {
    inherit prefs;
    prefsJson = builtins.toJSON (
      lib.filterAttrsRecursive (n: v: !builtins.elem (builtins.typeOf v) [ "lambda" ]) prefsAttr.pure
    );
  };
  security = {
    polkit = {
      extraConfig = ''
        polkit.addRule(function (action, subject) {
          if (action.id == "net.reactivated.fprint.device.enroll") {
            return polkit.Result.YES
          }
        })
      '';
    };
    pki = {
      certificateFiles =
        let
          mitmCA = lib.optionals (builtins.pathExists impure.mitmproxyCAFile) [
            (builtins.toFile "mitmproxy-ca.pem" (builtins.readFile impure.mitmproxyCAFile))
          ];
          CAs = [ ];
        in
        mitmCA ++ CAs;
    };
    pam = {
      sshAgentAuth = {
        enable = true;
      };
      u2f = {
        enable = prefs.enablePamU2f;
      };
      mount = {
        enable = prefs.enablePamMount;
        extraVolumes = [
          ''<luserconf name=".pam_mount.conf.xml" />''
          ''<fusemount>${pkgs.fuse}/bin/mount.fuse %(VOLUME) %(MNTPT) "%(before=\"-o \" OPTIONS)"</fusemount>''
          "<fuseumount>${pkgs.fuse}/bin/fusermount -u %(MNTPT)</fuseumount>"
          "<path>${pkgs.fuse}/bin:${pkgs.coreutils}/bin:${pkgs.util-linux}/bin:${pkgs.gocryptfs}/bin</path>"
        ];
      };
      services = {
        "${prefs.owner}" = {
          fprintAuth = prefs.enableFprintd;
          limits = [
            {
              domain = "*";
              type = "hard";
              item = "nofile";
              value = "131 071";
            }
            {
              domain = "*";
              type = "soft";
              item = "nofile";
              value = "131 071";
            }
          ];
          enableGnomeKeyring = prefs.enableGnomeKeyring;
          pamMount = prefs.enablePamMount;
          sshAgentAuth = true;
          setEnvironment = true;
        };

        root = {
          sshAgentAuth = true;
        };
      };
    };
    # rtkit is optional but recommended for pipewire
    rtkit.enable = true;
  };

  networking = {
    resolvconf = {
      dnsExtensionMechanism = false;
    };
    nftables = {
      enable = true;
    };
    useNetworkd = prefs.enableSystemdNetworkd;
    hostName = prefs.hostname;
    hostId = prefs.hostId;
    firewall.enable = prefs.enableFirewall;
    wg-quick =
      let
        peers = with builtins; fromJSON (readFile (./.. + "/fixtures/wireguard.json"));
        generateConfig = wireguardInstanceIndex: wireguardHostIndex: {
          inherit peers;
          address = [ "10.233.0.${builtins.toString wireguardHostIndex}/16" ];
          listenPort = 51820 + wireguardInstanceIndex;
          privateKeyFile = "/run/wireguard-private-key";
          postUp = [ "/run/secrets/wireguard-post-up" ];
        };
      in
      {
        interfaces = lib.optionalAttrs prefs.enableWireguard {
          wg0 = generateConfig 0 prefs.wireguardHostIndex;
        };
      };
    proxy.default = prefs.proxy;
    enableIPv6 = prefs.enableIPv6;
  }
  // (mergeOptionalConfigs [
    {
      enable = prefs.enableSupplicant;
      config = {
        wireless = {
          enable = true;
        };
        supplicant = {
          "WLAN" = {
            configFile = {
              writable = true;
            };
          };
        };
      };
    }
    {
      enable = prefs.enableIwd;
      config = {
        wireless = {
          iwd = {
            enable = true;
            settings = {
              Settings = {
                AutoConnect = true;
              };
            };
          };
        };
      };
    }
  ]);

  console = {
    font =
      if prefs.consoleFont != null then
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
  }
  // (mergeOptionalConfigs [
    {
      enable = prefs.enableInputMethods;
      config = {
        inputMethod = {
          enable = true;
          type = prefs.enabledInputMethod;
          ibus.engines = with pkgs.ibus-engines; [
            libpinyin
            table
            table-chinese
            table-others
          ];
          fcitx5.addons = with pkgs; [
            qt6Packages.fcitx5-chinese-addons
            fcitx5-rime
            fcitx5-table-extra
            fcitx5-table-other
          ];
        };
      };
    }
  ]);

  time = {
    timeZone = "Asia/Shanghai";
    hardwareClockInLocalTime = false;
  };

  environment = {
    etc = {
      "nix/path/nixpkgs".source = inputs.nixpkgs;
      "nix/path/nixpkgs-stable".source = inputs.nixpkgs-stable;
      "nix/path/nixpkgs-unstable".source = inputs.nixpkgs-unstable;
      "nix/path/home-manager".source = inputs.home-manager;
      "nix/path/activeconfig".source = inputs.self;
      "davfs2/secrets" = {
        enable = prefs.enableDavfs2 && builtins.pathExists prefs.davfs2Secrets;
        mode = "0600";
        source = prefs.davfs2Secrets;
      };
      "keyd/keyd.conf" = {
        text = ''
          [ids]
          *

          [main]
          capslock = layer(control)
          rightalt = layer(alt)
          leftmeta = layer(metaalt)
          rightmeta = oneshot(altgr)
          rightcontrol = layer(meta)

          space = overload(myspace, space)

          [metaalt:M-A]

          [myspace]
          w = home
          s = end
          n = pagedown
          p = pageup
          h = left
          j = down
          k = up
          l = right
          d = delete
          i = insert
          b = backspace
          o = enter
          e = escape
          m = menu
          t = tab
          c = capslock
        '';
        mode = "0644";
      };
      hosts.mode = "0644";
    }
    // (mergeOptionalConfigs [
      {
        enable = builtins.pathExists "${prefs.home}/Workspace/infra";
        config = {
          "nix/path/config".source = "${prefs.home}/Workspace/infra";
          "nix/path/infra".source = "${prefs.home}/Workspace/infra";
        };
      }
      {
        enable = prefs.enableCrio && prefs.enableZfs;
        config = {
          "crio/crio.conf.d/01-zfs.conf".text = ''
            [crio]
            storage_driver = "zfs"
          '';
        };
      }
      {
        enable = prefs.enableResolved;
        config = {
          "systemd/resolved.conf" = {
            mode = "0644";
          };
        };
      }
    ]);

    extraOutputsToInstall = prefs.extraOutputsToInstall;
    systemPackages =
      with pkgs;
      builtins.filter (x: x != null) (
        [
          man-pages
          fuse
          bindfs
          iptables
          iproute2
          ethtool
          nftables
          ipset
          dnsmasq
          wireguard-tools
          nixVersions.stable
          nix-info
          nixos-generators
          niv
          nix-serve
          (pkgs.myPackage.home-manager or home-manager)
          nixfmt-rfc-style
          nix-du
          nix-index
          nix-top
          fzf
          jq
          mailutils
          libnotify
          (pkgs.myPackages.lua or lua)
          # nodejs
          gdb
          gcc
          gnumake
          openssh
          trash-cli
          podman
          podman-compose
          arion
          skopeo
          usbutils
          powertop
          fail2ban
          ldns
          bind
          tree
          nix-prefetch-scripts
          # python3
          (pkgs.myPackages.pythonStable or python3)
          page
          (pkgs.myPackages.nvimdiff or null)
          ruby
          perl
          neovim
          vim
          libffi
          pciutils
          util-linux
          ntfs3g
          gnupg
          pinentry-curses
          pinentry-qt
          paperkey
          atool
          atop
          bash
          zsh
          ranger
          gptfdisk
          curl
          wget
          at
          git
          chezmoi
          coreutils
          file
          sudo
          gettext
          mimeo
          xdg-utils
          xdg-launch
          # libsecret
          mlocate
          htop
          iotop
          iftop
          nethogs
          iw
          lsof
          age
          sops
          dmidecode
          cachix
          e2fsprogs
          efibootmgr
          dbus
          cryptsetup
          exfat
          rsync
          rclone
          restic
          sshfs
          fcron
          gmp
          libcap
        ]
        ++ (mergeOptionalLists [
          {
            enable = !prefs.isMinimalSystem;
            list = [
              ly

              udiskie
              ydotool
              wev
              slurp
              # kanshi
              wayvnc
              # waypipe
              (pkgs.waylandPkgs.wlvncc or null)
              brightnessctl
              wl-clipboard
              wlroots
              wayland
              wayland-protocols
              wlr-randr
              wdisplays
              autotiling

              acpilight
              pulsemixer
              autokey

              keyd
              pixman
              libevdev

              lldb

              (pkgs.myPackages.deploy-rs or null)
              (pkgs.myPackages.nix-autobahn or null)
              # Not working for now
              # error: store path '/nix/store/7phspaj5lxw5qja709r5j3ivcllp0gk2-hyhhrcbzng0kgkyv63mqhznhrp67fhf5-source-crate2nix' is not allowed to have references
              # See https://github.com/NixOS/nix/issues/5647
              # (pkgs.myPackages.helix or helix)
              helix

              # adwaita-icon-theme
              # gnome.dconf
              # gnome.gsettings-desktop-schemas
              # gnome.zenity
              # font-manager

              dunst
              rofi
              picom
              blueman
              virt-manager
              fdm
              noti
              gparted

              bluez
              dmenu
              alacritty
              # gnome.seahorse
              pinentry-curses
              rxvt-unicode
              bluez-tools
              i3blocks
              i3lock
              i3status-rust
              firefox-devedition
              termite
              foot
            ];
          }
          {
            enable = prefs.enableTailScale;
            list = [ tailscale ];
          }
          {
            enable = prefs.enableCodeServer;
            list = [ code-server ];
          }
          {
            enable = prefs.enableZfs;
            list = [ zfsbackup ];
          }
          {
            enable = prefs.enableBtrfs;
            list = [
              btrbk
              btrfs-progs
            ];
          }
          {
            enable = prefs.enableDocker;
            list = [ docker-buildx ];
          }
          {
            enable = prefs.enableWstunnel;
            list = [ wstunnel ];
          }
          {
            enable = prefs.enableXmonad;
            list = [ xmobar ];
          }
          {
            enable = prefs.enableEmacs;
            list = [ emacs ];
          }
          {
            enable = !prefs.isMinimalSystem && prefs.nixosSystem == "x86_64-linux";
            list = [
              # steam-run-native
              # aqemu
              bpftools
              perf
              config.boot.kernelPackages.bpftrace
              config.boot.kernelPackages.bcc
              config.boot.kernelPackages.systemtap
            ];
          }
          {
            enable = prefs.enableActivityWatch;
            list = with inputs.jtojnar-nixfiles.packages.${prefs.nixosSystem}; [
              aw-server-rust
              aw-watcher-afk
              aw-watcher-window
            ];
          }
        ])
      );
    enableDebugInfo = prefs.enableDebugInfo;
    shellAliases = {
      ssh = "ssh -C";
      bc = "bc -l";
    };
    sessionVariables = lib.optionalAttrs (prefs.enableSessionVariables) (
      let
        systemPaths = [
          "/nix/var/nix/profiles/per-user/${prefs.owner}/home-manager/home-path"
          "/run/current-system/sw"
        ];
        getPaths =
          basePaths: subdirectories:
          let
            getFullPaths = basePath: builtins.map (subfolder: "${basePath}/${subfolder}") subdirectories;
          in
          builtins.concatMap getFullPaths basePaths;
        mkPaths =
          basePaths: subdirectories: separator:
          builtins.concatStringsSep separator (getPaths basePaths subdirectories);
        headerPath = mkPaths systemPaths [ "include" ] ":";
        ldLibraryPath =
          let
            paths1 = getPaths systemPaths [ "lib" ];
            paths2 =
              with pkgs;
              lib.makeLibraryPath [
                stdenv.cc.cc
              ];
            paths = paths1 ++ [ paths2 ];
          in
          builtins.concatStringsSep ":" paths;
        pkgconfigPath = mkPaths systemPaths [ "lib/pkgconfig" "share/pkgconfig" ] ":";
      in
      rec {
        MYSHELL = if prefs.enableZSH then "zsh" else "bash";
        MYTERMINAL = if prefs.enableUrxvtd then "urxvtc" else "alacritty";
        GOPATH = "$HOME/.go";
        CABALPATH = "$HOME/.cabal";
        CARGOPATH = "$HOME/.cargo";
        NODE_PATH = "$HOME/.node";
        PERLBREW_ROOT = "$HOME/.perlbrew-root";
        LOCALBINPATH = "$HOME/.local/bin";

        # help building locally compiled programs
        LIBRARY_PATH = ldLibraryPath;
        # Don't set LD_LIBRARY_PATH here, there will be various problems.
        MY_LD_LIBRARY_PATH = ldLibraryPath;
        # cmake does not respect LIBRARY_PATH
        CMAKE_LIBRARY_PATH = ldLibraryPath;
        CC_LIBRARY_PATH = ldLibraryPath;

        # header files
        CPATH = headerPath;
        C_INCLUDE_PATH = headerPath;
        CPLUS_INCLUDE_PATH = headerPath;
        CMAKE_INCLUDE_PATH = headerPath;

        # pkg-config
        PKG_CONFIG_PATH = pkgconfigPath;

        PATH = [
          "$HOME/.bin"
          "$HOME/.local/bin"
        ]
        ++ (map (x: x + "/bin") [
          CABALPATH
          CARGOPATH
          GOPATH
        ])
        ++ [ "${NODE_PATH}/node_modules/.bin" ]
        ++ [ "/usr/local/bin" ];
        LESS = "-x4RFsX";
        PAGER = "less";
        EDITOR = "nvim";
      }
      // (mergeOptionalConfigs [
        {
          enable = pkgs ? myPackages;
          config = {
            # export PYTHONPATH="$MYPYTHONPATH:$PYTHONPATH"
            MYPYTHONPATH =
              (pkgs.myPackages.pythonPackages.makePythonPath or pkgs.python3Packages.makePythonPath)
                [ (pkgs.myPackages.python or pkgs.python) ];
          };
        }
      ])
      // (mergeOptionalConfigs [
        {
          enable = nvidiaEnabled;
          config = {
            CUDA_PATH = "${pkgs.cudatoolkit}";
            CUDA_TOOLKIT_ROOT_DIR = "${pkgs.cudatoolkit}";
          };
        }
      ])
      // (mergeOptionalConfigs [
        {
          enable = prefs.enableYdotool;
          config = {
            YDOTOOL_SOCKET = "/run/ydotoold/socket";
          };
        }
      ])
    );
  };

  programs = {
    ccache = {
      enable = prefs.enableCcache;
    };
    java = {
      enable = prefs.enableJava;
    };
    ydotool = {
      enable = prefs.enableYdotool;
      group = "wheel";
    };
    gnupg.agent = {
      enable = prefs.enableGPGAgent;
      enableExtraSocket = true;
      enableBrowserSocket = true;
    };
    sysdig = {
      enable = prefs.enableSysdig;
    };
    ssh = {
      startAgent = true;
      extraConfig = ''
        Include ssh_config.d/*
      '';
    };
    # vim.defaultEditor = true;
    adb.enable = prefs.enableADB;
    slock.enable = prefs.enableSlock;
    bash = {
      completion = {
        enable = true;
      };
    };
    fish = {
      enable = prefs.enableFish;
    };
    nix-ld = {
      enable = prefs.enableNixLd;
      libraries =
        options.programs.nix-ld.libraries.default
        ++ (with pkgs; [
          libglvnd
          glib
        ])
        ++ (with config.hardware.graphics; if enable then [ package ] else [ ])
        ++ config.hardware.graphics.extraPackages
        ++ (
          if nvidiaEnabled then
            with pkgs;
            with cudaPackages;
            [
              cudatoolkit
              cudnn
              libcublas
            ]
          else
            [ ]
        );
    };
    zsh = {
      enable = prefs.enableZSH;
      enableCompletion = true;
      ohMyZsh = {
        enable = true;
      };
      shellInit = "zsh-newuser-install() { :; }";
    };
    # light.enable = true;
    sway =
      let
        # Fix screen tearing in external display of machine with nvidia GPU
        # https://old.reddit.com/r/swaywm/comments/z98btz/external_monitor_finally_working_with_glitches/kjusdq6/
        nvidiaArgs =
          if nvidiaEnabled then
            [
              "--unsupported-gpu"
              "-Dlegacy-wl-drm"
            ]
          else
            [ ];
        nvidiaEnv =
          if nvidiaEnabled then
            ''
              export WLR_NO_HARDWARE_CURSORS=1
            ''
          else
            "";
      in
      {
        enable = prefs.enableSway;
        extraOptions = [
          "--verbose"
          "--debug"
        ]
        ++ nvidiaArgs;
        extraPackages = with pkgs; [
          swaylock
          swaybg
          swayidle
          wlrctl
          wlsunset
          i3status-rust
          termite
          alacritty
          rofi
          bemenu
          grim
          drm_info
          jq
          coreutils
          gawk
          gnused
          gnugrep
        ];
        extraSessionCommands = ''
          # For debugging purpose, if the environment variable SWAY_SKIP_SETTING_ENV is set,
          # sway will not set the environment variables.
          if [[ -z "$SWAY_SKIP_SETTING_ENV" ]]; then
            # see also https://wiki.hyprland.org/Configuring/Environment-variables/

            # Fix screen tearing in external display of machine with nvidia GPU
            # https://old.reddit.com/r/swaywm/comments/102cdqa/how_can_i_fix_my_external_screen_flickering_with/
            # Seems to be not working
            # export WLR_RENDERER=vulkan

            export TERMINAL="alacritty"
            export BROWSER="firefox-devedition"

            export _JAVA_AWT_WM_NONREPARENTING=1
            export QT_AUTO_SCREEN_SCALE_FACTOR=1
            export QT_QPA_PLATFORM="wayland;xcb"
            export QT_WAYLAND_DISABLE_WINDOWDECORATION=1
            export GDK_BACKEND=wayland,x11,*
            export XDG_CURRENT_DESKTOP=sway
            export MOZ_ENABLE_WAYLAND=1
            export CLUTTER_BACKEND=wayland
            export SDL_VIDEODRIVER=wayland

            export GTK_IM_MODULE=fcitx
            export QT_IM_MODULE=fcitx
            export XMODIFIERS=@im=fcitx

            # https://wiki.hyprland.org/Nvidia/
            export NIXOS_OZONE_WL=1

            # https://discourse.nixos.org/t/nixos-ozone-wl-1-seemingly-not-having-any-affect/56776/3
            export ELECTRON_OZONE_PLATFORM_HINT=wayland

            # https://github.com/swaywm/sway/issues/5008
            # export WLR_DRM_NO_MODIFIERS=1
            # https://wiki.archlinux.org/title/Wayland#Requirements
            # export GBM_BACKEND=nvidia-drm
            # export __GLX_VENDOR_LIBRARY_NAME=nvidia

            # https://old.reddit.com/r/swaywm/comments/17sob2b/sway_wont_launch_with_vulkan_renderer_on_nvidia/k8rkxo4/
            nvidia_priority=40
            # If $WLR_RENDERER == vulkan, then the nvidia card should be prioritized to the first
            # otherwise, nvidia card should be deprioritized to the last.
            if [[ "$WLR_RENDERER" == "vulkan" ]]; then
              nvidia_priority=40
            fi
            # https://wiki.hyprland.org/hyprland-wiki/pages/Configuring/Multi-GPU/
            wlr_drm_devices="$(drm_info -j |\
              jq -r 'with_entries(.value |= .driver.desc) | to_entries | .[] | "\(.key) \(.value)"' |\
              sed -E "s#(^\S+)\s+(.*intel.*)#\1 10#gI;
                s#(^\S+)\s+(.*amd.*)#\1 20#gI;
                s#(^\S+)\s+(.*nvidia.*)#\1 $nvidia_priority#gI;
                s#(^\S+)\s+([^0-9]+$)#\1 30#gI" |\
              sort -n -k2 |\
              awk '{print $1}' |\
              paste -sd ':')"
            if [[ -n "$wlr_drm_devices" ]]; then
              export WLR_DRM_DEVICES="$wlr_drm_devices"
            fi

            ${nvidiaEnv}
          fi
        '';
      };
    tmux = {
      enable = true;
    };
    wireshark.enable = prefs.enableWireshark;
  };

  fonts = {
    enableDefaultPackages = true;
    # fontDir.enable = true;
    fontconfig = {
      enable = prefs.enableFontConfig;
    };
    packages =
      if prefs.isMinimalSystem then
        [ ]
      else
        (with pkgs; [
          wqy_microhei
          wqy_zenhei
          source-han-sans
          source-han-serif
          arphic-ukai
          arphic-uming
          noto-fonts-cjk-sans
          inconsolata
          ubuntu-classic
          hasklig
          fira-code
          fira-code-symbols
          cascadia-code
          jetbrains-mono
          corefonts
          source-code-pro
          source-sans-pro
          source-serif-pro
          noto-fonts-color-emoji
          lato
          line-awesome
          material-icons
          material-design-icons
          font-awesome
          font-awesome_4
          fantasque-sans-mono
          dejavu_fonts
          terminus_font
        ]);
  };

  nixpkgs =
    let
      cross =
        if prefs.enableAarch64Cross then
          rec {
            crossSystem = (import <nixpkgs> { }).pkgsCross.aarch64-multiplatform.stdenv.targetPlatform;
            localSystem = crossSystem;
          }
        else
          { };
      configAttr = { };
    in
    configAttr // cross;

  hardware = {
    enableAllFirmware = prefs.enableAllFirmware;
    enableRedistributableFirmware = prefs.enableRedistributableFirmware;
    graphics = {
      enable = prefs.enableGraphics;
    };
    bumblebee = {
      enable = prefs.enableBumblebee;
      connectDisplay = true;
    };
    bluetooth = {
      enable = prefs.enableBluetooth;
      powerOnBoot = prefs.enableBluetooth;
    };
    acpilight = {
      enable = prefs.enableAcpilight;
    };
  };

  location = {
    latitude = 39.55;
    longitude = 116.23;
  };

  system = {
    activationScripts = {
      # Diff system changes on switch. Taken from
      # https://github.com/luishfonseca/dotfiles/blob/6193dff46ad05eca77dedba9afbc50443a8b3dd1/modules/upgrade-diff.nix
      diff = {
        supportsDryActivation = true;
        text = ''
          echo ${pkgs.nvd}/bin/nvd --nix-bin-dir=${pkgs.nix}/bin diff /run/current-system "$systemConfig"
          ${pkgs.nvd}/bin/nvd --nix-bin-dir=${pkgs.nix}/bin diff /run/current-system "$systemConfig"
        '';
      };
      mkCcacheDirs = {
        text = "install -d -m 0777 -o root -g nixbld /var/cache/ccache";
        deps = [ ];
      };
      usrlocalbin = {
        text = "mkdir -m 0755 -p /usr/local/bin";
        deps = [ ];
      };
      local = {
        text = "mkdir -m 0755 -p /local/bin && mkdir -m 0755 -p /local/lib && mkdir -m 0755 -p /local/jdks";
        deps = [ ];
      };
      cclibs = {
        text = "cd /local/lib; for i in ${pkgs.gcc.cc.lib}/lib/*; do ln -sfn $i; done";
        deps = [ "local" ];
      };

      # Fuck /bin/bash
      binbash = {
        text = "ln -sfn ${pkgs.bash}/bin/bash /bin/bash";
        deps = [ "binsh" ];
      };

      # I may want to temporarily change /usr/bin/env
      binenv = {
        text = "ln -sfn ${pkgs.coreutils}/bin/env /bin/env";
        deps = [ "binsh" ];
      };

      # sftpman
      mntsshfs = {
        text = "install -d -m 0700 -o ${prefs.owner} -g ${prefs.ownerGroup} /mnt/sshfs";
        deps = [ ];
      };

      # rclone
      mntrclone = {
        text = "install -d -m 0700 -o ${prefs.owner} -g ${prefs.ownerGroup} /mnt/rclone";
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

      # make some symlinks to /bin, just for convenience
      binShortcuts = {
        text = ''
          ln -sfn ${pkgs.neovim}/bin/nvim /usr/local/bin/nv
        '';
        deps = [
          "binsh"
          "usrlocalbin"
        ];
      };
    }
    // (mergeOptionalConfigs [
      {
        enable = prefs.enableJava;
        config =
          let
            addjdk =
              jdk:
              if pkgs ? jdk then
                let
                  p = pkgs.${jdk}.home;
                in
                "ln -sfn ${p} /local/jdks/${jdk}"
              else
                lib.warn "jdk ${jdk} does not exists" "";
          in
          {
            jdks = {
              text = lib.concatMapStringsSep "\n" addjdk prefs.linkedJdks;
              deps = [ "local" ];
            };
          };
      }
      {
        enable = !prefs.enableNixLd;
        config = {
          # Fuck pre-built dynamic binaries
          # copied from https://github.com/NixOS/nixpkgs/pull/69057
          ldlinux = {
            text =
              with lib;
              concatStrings (
                mapAttrsToList
                  (target: source: ''
                    mkdir -m 0755 -p $(dirname ${target})
                    ln -sfn ${escapeShellArg source} ${target}.tmp
                    mv -f ${target}.tmp ${target} # atomically replace
                  '')
                  {
                    "i686-linux"."/lib/ld-linux.so.2" = "${pkgs.glibc.out}/lib/ld-linux.so.2";
                    "x86_64-linux"."/lib/ld-linux.so.2" = "${pkgs.pkgsi686Linux.glibc.out}/lib/ld-linux.so.2";
                    "x86_64-linux"."/lib64/ld-linux-x86-64.so.2" = "${pkgs.glibc.out}/lib64/ld-linux-x86-64.so.2";
                    "aarch64-linux"."/lib/ld-linux-aarch64.so.1" = "${pkgs.glibc.out}/lib/ld-linux-aarch64.so.1";
                    "armv7l-linux"."/lib/ld-linux-armhf.so.3" = "${pkgs.glibc.out}/lib/ld-linux-armhf.so.3";
                  }
                  .${pkgs.stdenv.system} or { }
              );
            deps = [ ];
          };
        };
      }
    ]);
  };

  services = {
    udev = {
      extraRules = prefs.extraUdevRules;
      packages = lib.optionals prefs.enableYubico [ pkgs.yubikey-personalization ];
    };
    blueman = {
      enable = prefs.enableBluetooth;
    };
    pcscd.enable = prefs.enablePcscd;
    arbtt = {
      enable = prefs.enableArbtt;
    };
    pulseaudio = {
      # Allow VM to override this
      enable = prefs.enablePulseaudio;
      package = pkgs.pulseaudioFull;
      support32Bit = true;
    };
    fprintd = {
      enable = prefs.enableFprintd;
    };
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
      install = prefs.enableOfflineimap;
      path = [
        pkgs.libsecret
        pkgs.dbus
      ];
    };
    nomad = {
      enable = prefs.enableNomad;
      settings = prefs.nomadSettings;
      dropPrivileges = true;
    };
    consul = {
      enable = prefs.enableConsul;
      interface = {
        advertise = prefs.consulInterface;
        bind = prefs.consulInterface;
      };
      webUi = prefs.enableConsulWebUi;
      dropPrivileges = true;
    };
    chrony = {
      enable = prefs.enableChrony;
      extraConfig = ''
        makestep 0.1 3
      '';
    };
    ntp = {
      enable = !config.services.chrony.enable;
    };
    pipewire = {
      enable = prefs.enablePipewire;
      audio = {
        enable = true;
      };
      alsa = {
        enable = true;
        support32Bit = true;
      };
      pulse = {
        enable = true;
      };
      wireplumber = {
        enable = true;
      };
    };
    restic = {
      backups = lib.optionalAttrs prefs.enableResticBackup (
        let
          restic-exclude-files = pkgs.writeTextFile {
            name = "restic-excluded-files";
            text = ''
              ltximg
              .stversions
              .st folder
              .sync
              .syncthing.*.tmp
              ~syncthing~*.tmp
              .elixir_ls
              *.beam
              _build
              .DS_Store
              _internal_bibisco_projects_db_
              .emacs.d/straight
              *.aux
              *.lof
              *.log
              *.lot
              *.fls
              *.out
              *.toc
              *.fmt
              *.fot
              *.cb
              *.cb2
              .*.lb
              *.dvi
              *.xdv
              *-converted-to.*
              *.bbl
              *.bcf
              *.blg
              *-blx.aux
              *-blx.bib
              *.run.xml
              *.fdb_latexmk
              *.synctex
              *.synctex(busy)
              *.synctex.gz
              *.synctex.gz(busy)
              *.organice-bak
              *.md~
            '';
          };
          go = name: conf: rcloneBackend: backendName: {
            "${name}-${backendName}" = {
              initialize = false;
              passwordFile = "/run/secrets/restic-password";
              repository = "rclone:${rcloneBackend}:restic";
              rcloneConfigFile = "/run/secrets/rclone-config";
              timerConfig = {
                OnCalendar = "00:05";
                RandomizedDelaySec = 3600 * 8;
              };
            }
            // conf;
          };
          commonFlags = [
            "-v=3"
            "--no-lock"
            "--exclude-file=${restic-exclude-files}"
          ];
          mkBackup =
            {
              name,
              config,
              enable ? true,
            }:
            lib.optionalAttrs enable (
              go name config "backup-primary" "primary" // go name config "backup-secondary" "secondary"
            );
        in
        builtins.foldl' (acc: e: acc // mkBackup e) { } [
          {
            # Fake restic unit to prune old snapshots.
            # Do not use this on too many hosts, as prune locks the whole repository,
            # it may block normal backups.
            name = "prune";
            enable = prefs.enableResticPrune;
            config = {
              dynamicFilesFrom = ''
                #! ${pkgs.stdenv.shell}
                set -euo pipefail
                file="$CACHE_DIRECTORY/pruneTime";
                date -R > $file;
                echo "$file"
              '';
              timerConfig = {
                OnCalendar = "monthly";
                RandomizedDelaySec = 3600 * 24 * 7;
              };
              pruneOpts = [
                "--keep-daily 7 --keep-weekly 5 --keep-monthly 12 --keep-yearly 75"
              ];
              extraBackupArgs = commonFlags;
            };
          }
          {
            # Fake restic unit to do some maintenance work for repo.
            name = "maintenance";
            config = {
              backupPrepareCommand = ''
                export PATH="${pkgs.restic}/bin:$PATH"
                # Try to unlock the repo restic frequently exits with the repo remains locked.
                # This may fail on a racing or before restic is initialized
                if ! restic unlock >& "$CACHE_DIRECTORY/unlock.log"; then
                    :
                fi
                # Simple hack to ensure restic is initialized,
                # The command take quite a while, so we only run this on file not existing.
                if ! [[ -f "$CACHE_DIRECTORY/initialized" ]]; then
                    restic snapshots || restic init
                    touch "$CACHE_DIRECTORY/initialized"
                fi
              '';
              dynamicFilesFrom = ''
                #! ${pkgs.stdenv.shell}
                set -euo pipefail
                file="$CACHE_DIRECTORY/maintainTime";
                date -R > $file;
                echo "$file"
              '';
              timerConfig = {
                OnCalendar = "weekly";
                RandomizedDelaySec = 3600 * 24 * 7;
              };
              extraBackupArgs = commonFlags;
            };
          }
          {
            name = "vardata";
            config = {
              extraBackupArgs = commonFlags ++ [
                "--exclude=/postgresql"
                "--exclude=/vault/logs"
                "--exclude=/nextcloud-data"
                "--exclude=/sftpgo/data"
                "--exclude=/sftpgo/backups"
              ];
              paths = [ "/var/data" ];
            };
          }
          {
            name = "sync";
            config = {
              extraBackupArgs = commonFlags ++ [
                "--exclude-larger-than=500M"
                "--exclude=.git"
              ];
              paths = [ "${prefs.syncFolder}" ];
            };
          }
        ]
      );
    };
    glusterfs = {
      enable = prefs.enableGlusterfs;
      tlsSettings = {
        caCert = "/run/secrets/cfssl-ca-pem";
        tlsKeyPath = "/run/secrets/glusterfs-cert-key";
        tlsPem = "/run/secrets/glusterfs-cert";
      };
    };
    cadvisor = {
      enable = prefs.enableCadvisor;
      port = prefs.cadvisorPort;
      extraOptions = prefs.cadvisorExtraOptions;
    };
    davfs2 = {
      enable = prefs.enableDavfs2;
    };
    dnsmasq = {
      enable = prefs.enableDnsmasq;
      resolveLocalQueries = prefs.dnsmasqResolveLocalQueries;
      settings = {
        servers = prefs.dnsmasqServers;
        listen-address = prefs.dnsmasqListenAddress;
        bind-interfaces = true;
        cache-size = 1000;
      };
    };
    smartdns = {
      enable = prefs.enableSmartdns;
      settings = prefs.smartdnsSettings;
    };
    urxvtd = {
      enable = prefs.enableUrxvtd;
    };
    resolved = {
      enable = prefs.enableResolved;
      dnssec = "false";
      extraConfig = builtins.concatStringsSep "\n" [
        ''
          DNS=${builtins.concatStringsSep " " prefs.dnsServers}
        ''
      ];
    };
    x2goserver = {
      enable = prefs.enableX2goServer;
    };
    openssh = {
      enable = true;
      allowSFTP = true;
      settings = {
        X11Forwarding = prefs.enableSshX11Forwarding;
        GatewayPorts = "yes";
        PermitRootLogin = "yes";
        UseDns = true;
      };
      startWhenNeeded = true;
      extraConfig = builtins.concatStringsSep "\n" (
        [ "Include /etc/ssh/sshd_config.d/*" ]
        ++ (lib.optionals prefs.enableSshPortForwarding [
          ''
            Match User ssh-port-forwarding
              # PermitTunnel no
              # GatewayPorts no
              AllowTcpForwarding yes
              AllowStreamLocalForwarding yes
              X11Forwarding no
              AllowAgentForwarding no
              StreamLocalBindMask 0110
              StreamLocalBindUnlink yes
          ''
        ])
      );
    };
    ttyd = {
      enable = prefs.enableTtyd;
      clientOptions = {
        fontSize = "16";
      };
    };
    samba = {
      enable = prefs.enableSamba;
      settings = {
        global = {
          workgroup = "WORKGROUP";
          security = "user";
        };
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
      settings = {
        listen-address = "0.0.0.0:8118";
      };
    };
    redshift = {
      enable = prefs.enableRedshift;
    };
    avahi = {
      enable = prefs.enableAvahi;
      nssmdns4 = true;
      ipv6 = false;
      hostName = prefs.avahiHostname;
      extraConfig = ''
        [server]
        deny-interfaces=virbr0,docker0
      '';
      publish = {
        enable = true;
        userServices = true;
        addresses = true;
        hinfo = true;
        workstation = true;
      };
      extraServiceFiles =
        (builtins.foldl'
          (
            a: t:
            a
            // {
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
            }
          )
          { }
          [
            "ssh"
            "sftp-ssh"
          ]
        )
        // {
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
    nfs = {
      settings = {
        nfsd = {
          udp = true;
        };
      };
      server = {
        enable = prefs.enableNfs;
      };
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
    syncoid = {
      enable = prefs.enableSyncoid;
      commands = prefs.syncoidCommands;
      localSourceAllow = options.services.syncoid.localSourceAllow.default;
      localTargetAllow = options.services.syncoid.localTargetAllow.default ++ [
        "destroy"
        "dedup"
      ];
      commonArgs = [ "--debug" ];
    };
    sanoid = {
      enable = prefs.enableSanoid;
      datasets = prefs.sanoidDatasets;
    };

    sing-box = {
      enable = prefs.enableSingBox;
    };

    prometheus = {
      enable = prefs.enablePrometheus;
      extraFlags = [
        "--enable-feature=expand-external-labels"
      ]
      ++ (if prefs.enablePrometheusAgent then [ "--enable-feature=agent" ] else [ ]);
      port = prefs.prometheusPort;
      exporters = {
        node = {
          enable = prefs.enablePrometheusExporters;
          extraFlags = [ "--collector.netdev.address-info" ];
          enabledCollectors = [
            "ethtool"
            "interrupts"
            "ksmd"
            "lnstat"
            "logind"
            "network_route"
            "ntp"
            # TODO: perf does not work because of permission
            # node_exporter[3667114]: panic: Couldn't create metrics handler: couldn't create collector: Failed to setup CPU cycle profiler: pid (-1) cpu (0) "permission denied"; Failed to CPU setup instruction profiler: pid (-1) cpu (0) "permission denied"; Failed to setup cache ref profiler: pid (-1) cpu (0) "permission denied"; Failed to setup cache misses profiler: pid (-1) cpu (0) "permission denied"; Failed to setup branch instruction profiler: pid (-1) cpu (0) "permission denied"; Failed to setup branch miss profiler: pid (-1) cpu (0) "permission denied"; Failed to setup bus cycles profiler: pid (-1) cpu (0) "permission denied"; Failed to setup stalled fronted cycles profiler: pid (-1) cpu (0) "no such file or directory"; Failed to setup stalled backend cycles profiler: pid (-1) cpu (0) "no such file or directory"; Failed to setup ref CPU cycles profiler: pid (-1) cpu (0) "permission denied"
            # "perf"
            "processes"
            "qdisc"
            "systemd"
            "wifi"
          ];
        };
        domain = {
          enable = prefs.enablePrometheusExporters;
        };
        systemd = {
          enable = prefs.enablePrometheusExporters;
        };
        smartctl = rec {
          # Devices will be used generate systemd unit DeviceAllow, without which
          # smartctl exporter will fail with permission denied
          enable = prefs.enableSmartctlExporter && devices != [ ];
          devices = prefs.smartctlExporterDevices;
          listenAddress = "127.0.0.1";
        };
        wireguard = {
          enable = prefs.enablePrometheusExporters && prefs.enableWireguard;
        };
        postfix = {
          enable = prefs.enablePrometheusExporters && prefs.enablePostfix;
        };
        blackbox = {
          enable = prefs.enablePrometheusExporters;
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
              # Technically not 3xx
              http_3xx = {
                http = {
                  valid_status_codes = [
                    301
                    302
                    303
                    304
                    307
                    308
                  ];
                  follow_redirects = false;
                };
                prober = "http";
                timeout = "5s";
              };
              http_404 = {
                http = {
                  valid_status_codes = [ 404 ];
                };
                prober = "http";
                timeout = "5s";
              };
              http_header_match_origin = {
                http = {
                  fail_if_header_not_matches = [
                    {
                      allow_missing = false;
                      header = "Access-Control-Allow-Origin";
                      regexp = "(\\*|example\\.com)";
                    }
                  ];
                  headers = {
                    Origin = "example.com";
                  };
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
                icmp = {
                  preferred_ip_protocol = "ip4";
                };
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
                  query_response = [ { expect = "^+OK"; } ];
                  tls = true;
                  tls_config = {
                    insecure_skip_verify = false;
                  };
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
                tcp = {
                  query_response = [ { expect = "^SSH-2.0-"; } ];
                };
                timeout = "5s";
              };
              tcp_connect = {
                prober = "tcp";
                timeout = "5s";
              };
            };
          };
        };
      };
      remoteWrite = [
        {
          url = "https://prometheus-prod-10-prod-us-central-0.grafana.net/api/prom/push";
          basic_auth = {
            password_file = "/run/secrets/prometheus-remote-write-password";
            username = "205817";
          };
        }
      ];
      scrapeConfigs =
        let
          scrape =
            {
              name,
              enable,
              port,
            }:
            lib.optionals enable [
              {
                job_name = name;
                static_configs = [
                  {
                    targets = [ "127.0.0.1:${toString port}" ];
                    labels = {
                      nodename = prefs.hostname;
                    };
                  }
                ];
              }
            ];
          simpleScrape =
            name: with config.services.prometheus.exporters."${name}"; scrape { inherit name enable port; };
        in
        builtins.concatMap simpleScrape [
          "node"
          "wireguard"
          "postfix"
          "postgres"
          "systemd"
          "smartctl"
        ]
        ++ builtins.concatMap scrape [
          {
            name = "docker";
            enable = prefs.enableDockerMetrics;
            port = prefs.dockerMetricsPort;
          }
          {
            name = "cadvisor";
            enable = prefs.enableCadvisor;
            port = prefs.cadvisorPort;
          }
        ]
        ++ lib.optionals config.services.prometheus.exporters.blackbox.enable (
          let
            go =
              {
                name,
                targets,
                module ? [ "http_2xx" ],
                enable ? true,
              }:
              lib.optionals enable [
                {
                  job_name = name;
                  metrics_path = "/probe";
                  params = { inherit module; };
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
                      replacement = "127.0.0.1:${builtins.toString config.services.prometheus.exporters.blackbox.port}";
                      target_label = "__address__";
                    }
                  ];
                  static_configs = [
                    {
                      inherit targets;
                      labels = {
                        nodename = prefs.hostname;
                      };
                    }
                  ];
                }
              ];
          in
          builtins.concatMap go [
            {
              name = "blackbox_public_websites";
              targets = [
                "https://startpage.com"
                "https://www.baidu.com"
                "http://neverssl.com"
              ];
            }
            {
              name = "blackbox_edge_proxies";
              module = [ "http_3xx" ];
              targets = builtins.map (p: "http://${p}") prefs.edgeProxyHostnames;
            }
          ]
        )
        ++ lib.optionals config.services.prometheus.exporters.domain.enable [
          {
            job_name = "domain";
            metrics_path = "/probe";
            relabel_configs = [
              {
                source_labels = [ "__address__" ];
                target_label = "__param_target";
              }
              {
                replacement = "127.0.0.1:${builtins.toString config.services.prometheus.exporters.domain.port}";
                target_label = "__address__";
              }
            ];
            static_configs = [ { targets = [ prefs.mainDomain ]; } ];
          }
        ];
    };

    promtail = {
      enable = prefs.enablePromtail;
      extraFlags = [ "-config.expand-env=true" ];
      configuration = {
        server = {
          http_listen_port = prefs.promtailHttpPort;
          grpc_listen_port = prefs.promtailGrpcPort;
        };
        clients = [
          { url = "\${LOKI_URL}"; }
        ]
        ++ (lib.optionals prefs.enableLoki [
          {
            url = "http://127.0.0.1:${builtins.toString prefs.lokiHttpPort}/loki/api/v1/push";
          }
        ]);
        positions = {
          "filename" = "/var/cache/promtail/positions.yaml";
        };
        scrape_configs = [
          {
            job_name = "journal";
            journal = {
              labels = {
                job = "journald";
                nodename = prefs.hostname;
              };
              max_age = "12h";
            };
            relabel_configs = [
              {
                source_labels = [ "__journal__boot_id" ];
                target_label = "boot_id";
              }
              {
                source_labels = [ "__journal__comm" ];
                target_label = "command";
              }
              {
                source_labels = [ "__journal__cmdline" ];
                target_label = "command_line";
              }
              {
                source_labels = [ "__journal__exe" ];
                target_label = "executable";
              }
              {
                source_labels = [ "__journal__hostname" ];
                target_label = "nodename";
              }
              {
                source_labels = [ "__journal__systemd_unit" ];
                target_label = "systemd_unit";
              }
              {
                source_labels = [ "__journal__systemd_user_unit" ];
                target_label = "systemd_user_unit";
              }
              {
                source_labels = [ "__journal__syslog_identifier" ];
                target_label = "syslog_identifier";
              }
              {
                source_labels = [ "__journal_priority" ];
                target_label = "journal_priority";
              }
              {
                source_labels = [ "__journal__transport" ];
                target_label = "journal_transport";
              }
              {
                source_labels = [ "__journal_image_name" ];
                target_label = "container_image_name";
              }
              {
                source_labels = [ "__journal_container_name" ];
                target_label = "container_name";
              }
              {
                source_labels = [ "__journal_container_id" ];
                target_label = "container_id";
              }
              {
                source_labels = [ "__journal_container_tag" ];
                target_label = "container_tag";
              }
            ];
          }
        ];
      };
    };

    loki = {
      enable = prefs.enableLoki;
      configuration = {
        auth_enabled = false;
        chunk_store_config = {
          max_look_back_period = "0s";
        };
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
              kvstore = {
                store = "inmemory";
              };
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
          ring = {
            kvstore = {
              store = "inmemory";
            };
          };
          rule_path = "/var/lib/loki/rules-temp";
          storage = {
            local = {
              directory = "/var/lib/loki/rules";
            };
            type = "local";
          };
        };
        schema_config = {
          configs = [
            {
              from = "2020-10-24";
              index = {
                period = "24h";
                prefix = "index_";
              };
              object_store = "filesystem";
              schema = "v11";
              store = "boltdb-shipper";
            }
          ];
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
          filesystem = {
            directory = "/var/lib/loki/chunks";
          };
        };
        table_manager = {
          retention_deletes_enabled = false;
          retention_period = "0s";
        };
      };
    };

    autossh = {
      sessions = lib.optionals (prefs.enableAutossh) (
        let
          go =
            nth: server:
            let
              sshPort = 22;
              autosshPorts = prefs.helpers.autossh {
                hostname = prefs.hostname;
                serverName = server;
              };
              extraArguments =
                let
                  getReverseArgument = port: "-R :${builtins.toString port}:localhost:${builtins.toString sshPort}";
                  reversePorts = builtins.concatStringsSep " " (
                    [ "-R /tmp/autossh-${prefs.hostname}-ssh.sock:localhost:${builtins.toString sshPort}" ]
                    ++ (builtins.map
                      (
                        x:
                        let
                          port = builtins.toString x;
                        in
                        "-R /tmp/autossh-${prefs.hostname}-${port}.sock:localhost:${port}"
                      )
                      [
                        22
                        80
                        443
                      ]
                    )
                    ++ (builtins.map (x: getReverseArgument x) autosshPorts)
                  );
                in
                "-i ${
                  config.sops.secrets."port-forwarding-id_ed25519".path
                } -o ServerAliveInterval=15 -o ServerAliveCountMax=4 -o ControlMaster=no -N -D ${
                  builtins.toString (prefs.autosshDynamicPortOffset + nth)
                } ${reversePorts} ${server}";
            in
            {
              extraArguments = extraArguments;
              name = server;
              user = prefs.owner;
            };
        in
        lib.imap0 go prefs.autosshServers
      );
    };
    eternal-terminal = {
      enable = prefs.enableEternalTerminal;
    };
    printing = {
      enable = prefs.enablePrinting;
      drivers = [ pkgs.hplip ];
    };
    tailscale = {
      enable = prefs.enableTailScale;
    };
    zerotierone = {
      enable = prefs.buildZerotierone || prefs.enableZerotierone;
      joinNetworks = prefs.zerotieroneNetworks;
    };
    system-config-printer.enable = prefs.enablePrinting;
    logind = {
      settings.Login = {
        HandleLidSwitchExternalPower = "ignore";
        HandlePowerKey = "suspend";
        RuntimeDirectorySize = "50%";
      };
    };
    postfix = {
      enable = prefs.enablePostfix;
      rootAlias = prefs.owner;
      settings.main = {
        myhostname = prefs.hostname;
        mydomain = "localdomain";
        mydestination = "$myhostname, localhost.$mydomain, localhost";
        mynetworks_style = "host";
        default_transport = "error: outside mail is not deliverable";
      };
    };
    clickhouse = {
      enable = prefs.enableClickhouse;
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
      ensureDatabases = [
        "nextcloud"
        "wallabag"
      ];
      ensureUsers = [
        {
          name = "nextcloud";
          ensurePermissions = {
            "DATABASE nextcloud" = "ALL PRIVILEGES";
          };
        }
        {
          name = "wallabag";
          ensurePermissions = {
            "DATABASE wallabag" = "ALL PRIVILEGES";
          };
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
    redis.servers.redis.enable = prefs.enableRedis;
    fail2ban.enable = prefs.enableFail2ban && config.networking.firewall.enable;
    mpd.enable = prefs.enableMpd;
    # mosquitto.enable = true;
    rsyncd.enable = prefs.enableRsyncd;
    # accounts-daemon.enable = prefs.enableAccountsDaemon || prefs.enableFlatpak;
    flatpak.enable = prefs.enableFlatpak;
    thermald = {
      enable = prefs.enableThermald;
    };
    gnome = {
      gnome-keyring.enable = prefs.enableGnomeKeyring;
    };

    locate = {
      enable = prefs.enableLocate;
      package = pkgs.mlocate;
      interval = "hourly";
      pruneBindMounts = true;
    };

    jupyterhub = with pkgs; {
      enable = prefs.enableJupyter;
      jupyterhubEnv = python3.withPackages (
        p: with p; [
          jupyterhub
          jupyterhub-systemdspawner
        ]
      );
      # TODO: the following will not produce the required binary like jupyterhub-singleuser
      # jupyterlabEnv = prefs.helpers.mkIfAttrExists pkgs "myPackages.jupyterlab";
      jupyterlabEnv = python3.withPackages (p: with p; [ jupyterhub ]);
      port = 8899;
      kernels = {
        python3Kernel =
          let
            env = python3.withPackages (
              p: with p; [
                ipykernel
                dask-gateway
                numpy
                scipy
              ]
            );
          in
          {
            displayName = "Python 3";
            argv = [
              "${env.interpreter}"
              "-m"
              "ipykernel_launcher"
              "-f"
              "{connection_file}"
            ];
            language = "python";
            logo32 = "${env}/${env.sitePackages}/ipykernel/resources/logo-32x32.png";
            logo64 = "${env}/${env.sitePackages}/ipykernel/resources/logo-64x64.png";
          };

        cKernel = (
          let
            env = python3.withPackages (p: with p; [ jupyter-c-kernel ]);
          in
          {
            displayName = "C";
            argv = [
              "${env.interpreter}"
              "-m"
              "jupyter_c_kernel"
              "-f"
              "{connection_file}"
            ];
            language = "c";
          }
        );

        rustKernel = {
          displayName = "Rust";
          argv = [
            "${evcxr}/bin/evcxr_jupyter"
            "--control_file"
            "{connection_file}"
          ];
          language = "Rust";
        };

        rKernel =
          let
            env = rWrapper.override {
              packages = with rPackages; [
                IRkernel
                ggplot2
              ];
            };
          in
          {
            displayName = "R";
            argv = [
              "${env}/bin/R"
              "--slave"
              "-e"
              "IRkernel::main()"
              "--args"
              "{connection_file}"
            ];
            language = "R";
          };

        ansibleKernel =
          with stable.pkgs;
          let
            # build failure on latest, see https://github.com/NixOS/nixpkgs/issues/138381
            env =
              (python3.withPackages (
                p: with p; [
                  ansible-kernel
                  ansible
                ]
              )).override
                (args: {
                  ignoreCollisions = true;
                });
          in
          {
            displayName = "Ansible";
            argv = [
              "${env.interpreter}"
              "-m"
              "ansible_kernel"
              "-f"
              "{connection_file}"
            ];
            language = "ansible";
          };

        bashKernel =
          let
            env = python3.withPackages (p: with p; [ bash_kernel ]);
          in
          {
            displayName = "Bash";
            argv = [
              "${env.interpreter}"
              "-m"
              "bash_kernel"
              "-f"
              "{connection_file}"
            ];
            language = "Bash";
          };

        nixKernel =
          let
            env = python3.withPackages (p: with p; [ nix-kernel ]);
          in
          {
            displayName = "Nix";
            argv = [
              "${env.interpreter}"
              "-m"
              "nix-kernel"
              "-f"
              "{connection_file}"
            ];
            language = "Nix";
          };

        rubyKernel = {
          displayName = "Ruby";
          argv = [
            "${iruby}/bin/iruby"
            "kernel"
            "{connection_file}"
          ];
          language = "ruby";
        };

        # TODO: Below build failed with
        # RPATH of binary /nix/store/ilhgzcydg3vn4mp7k5yawlsjwfpm8xi8-ihaskell-0.10.1.2/bin/ihaskell contains a forbidden reference to /build/
        haskellKernel =
          with pkgs;
          let
            env = haskellPackages.ghcWithPackages (p: with p; [ ihaskell ]);
            ihaskellSh = writeScriptBin "ihaskell" ''
              #! ${stdenv.shell}
              export GHC_PACKAGE_PATH="$(echo ${env}/lib/*/package.conf.d| tr ' ' ':'):$GHC_PACKAGE_PATH"
              export PATH="${lib.makeBinPath ([ env ])}:$PATH"
              ${env}/bin/ihaskell -l $(${env}/bin/ghc --print-libdir) "$@"
            '';
          in
          {
            displayName = "Haskell";
            argv = [
              "${ihaskellSh}/bin/ihaskell"
              "kernel"
              "{connection_file}"
              "+RTS"
              "-M3g"
              "-N2"
              "-RTS"
            ];
            language = "Haskell";
          };
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
      settings = {
        verbose-connections = true;
        transparent = false;
      };
    }
    // (
      let
        p = impure.sslhConfigFile;
      in
      lib.optionalAttrs (builtins.pathExists p) {
        settings = (builtins.readFile p);
      }
    );

    unifi.enable = prefs.enableUnifi;

    # gvfs.enable = prefs.enableGvfs;

    emacs = {
      # enable = prefs.enableEmacs;
      install = prefs.enableEmacs;
      package = pkgs.emacs;
    };

    syncthing =
      let
        devices = prefs.syncthingDevices;
      in
      {
        enable = prefs.enableSyncthing;
        user = prefs.owner;
        dataDir = prefs.home;
        overrideDevices = false;
        overrideFolders = false;

        settings = {
          defaults = {
            ignores =
              let
                fileContent = builtins.readFile (prefs.getDotfile "private_dot_stglobalignore");
                originalLines = lib.splitString "\n" fileContent;
                # I used # and // to comment lines
                # because this way I can share the ignore file in git and syncthing.
                isUseless = x: (lib.hasPrefix "//" x) || (lib.hasPrefix "#" x) || (x == "");
                fileLines = builtins.filter (x: !(isUseless x)) originalLines;
                lines = fileLines ++ prefs.syncthingIgnores;
              in
              {
                inherit lines;
              };
          };

          gui = {
            user = "e";
            # TODO: didn't find way to hide it, but this password has enough entropy.
            password = "$2a$10$20ol/13Gghbqq/tsEkEyGO.kJLgKsz2cJmC4Cccx.0Z1ECSYHO80O";
          };

          inherit devices;

          folders =
            let
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
              getFolderConfig =
                {
                  id,
                  enable,
                  excludedDevices,
                  config,
                }:
                lib.optionalAttrs enable (
                  {
                    inherit id;
                    devices = lib.subtractLists excludedDevices allDevices;
                    ignorePerms = false;
                    versioning = getVersioningPolicy id;
                  }
                  // config
                );
            in
            let
              c = builtins.mapAttrs (
                id: config:
                getFolderConfig {
                  inherit id;
                  enable = config.enable or true;
                  excludedDevices = config.excludedDevices or [ ];
                  config = builtins.removeAttrs config [
                    "enable"
                    "excludedDevices"
                  ];
                }
              ) prefs.syncFolders;
            in
            lib.filterAttrs (id: config: config != { }) c;
        };

      };

    # yandex-disk = { enable = prefs.enableYandexDisk; } // yandexConfig;

    seatd = {
      enable = prefs.enableSeatd;
      user = prefs.owner;
    };
    greetd = {
      enable = prefs.enableGreetd;
    }
    // lib.optionalAttrs prefs.enableSwayForGreeted {
      settings =
        let
          swayCommand = "systemd-cat -t sway sway";
        in
        {
          initial_session = {
            # Example of debugging sway.
            # user = "fallback";
            # command = "env SWAY_SKIP_SETTING_ENV=1 WLR_RENDERER=vulkan ${swayCommand}";
            user = prefs.owner;
            command = swayCommand;
          };
          default_session = {
            user = "greeter";
            command = "${pkgs.tuigreet}/bin/tuigreet --time --debug --cmd '${swayCommand}'";
          };
        };
    };
    libinput = {
      enable = prefs.enableLibInput;
      touchpad = {
        tapping = true;
        disableWhileTyping = true;
      };
    };
    displayManager = {
      sddm = {
        enable = prefs.enableSddm;
        enableHidpi = prefs.enableHidpi;
        autoNumlock = true;
      };
      gdm = {
        enable = prefs.enableGdm;
      };
    };
    xserver = {
      enable = prefs.enableXserver;
      verbose = lib.mkForce 7;
      autorun = true;
      exportConfiguration = true;
      xkb = {
        layout = "us";
      };
      dpi = prefs.dpi;
      # videoDrivers = [ "dummy" ] ++ [ "intel" ];
      virtualScreen = {
        x = 1200;
        y = 1920;
      };
      xautolock =
        let
          locker = "${pkgs.i3lock}/bin/i3lock";
          killer = "${pkgs.systemd}/bin/systemctl suspend";
          notifier = ''${pkgs.libnotify}/bin/notify-send "Locking in 10 seconds"'';
        in
        {
          inherit locker killer notifier;
          enable = prefs.enableXautolock;
          enableNotifier = true;
          nowlocker = locker;
        };
      # desktopManager.xfce.enable = true;
      # desktopManager.plasma5.enable = true;
      # desktopManager.xfce.enableXfwm = false;
      windowManager = {
        i3 = {
          enable = prefs.enableI3;
        };
        awesome.enable = prefs.enableAwesome;
      }
      // (lib.optionalAttrs prefs.enableXmonad {
        xmonad = {
          enable = true;
          enableContribAndExtras = true;
          extraPackages =
            haskellPackages: with haskellPackages; [
              xmobar
              # taffybar
              xmonad-contrib
              xmonad-extras
              xmonad-utils
              # xmonad-windownames
              # xmonad-entryhelper
              yeganesh
              libmpd
              dbus
            ];
        };
      });
      displayManager = {
        sessionCommands = prefs.xSessionCommands;
        startx = {
          enable = prefs.enableStartx;
        };
        lightdm = {
          enable = prefs.enableLightdm;
        };
      };
    }
    // (lib.optionalAttrs (prefs.videoDrivers != null) {
      inherit (prefs) videoDrivers;
    });
  };

  xdg = {
    mime = {
      enable = true;
      addedAssociations = {
        "application/pdf" = "firefox-devedition.desktop";
        "text/xml" = [
          "nvim.desktop"
          "codium.desktop"
        ];
      };
      defaultApplications = {
        "application/pdf" = [
          "org.pwmt.zathura.desktop"
          "qpdfview.desktop"
          "koreader.desktop"
          "sioyek.desktop"
        ];
        "image/vnd.djvu" = [
          "org.pwmt.zathura.desktop"
          "koreader.desktop"
        ];
        "image/vnd.djvu+multipage" = [
          "org.pwmt.zathura.desktop"
          "koreader.desktop"
        ];
        "application/oxps" = [
          "org.pwmt.zathura.desktop"
          "koreader.desktop"
        ];
        "application/epub+zip" = [
          "org.pwmt.zathura.desktop"
          "koreader.desktop"
        ];
        "application/x-fictionbook" = [
          "org.pwmt.zathura.desktop"
          "koreader.desktop"
        ];
        "image/bmp" = [
          "imv.desktop"
          "sxiv.desktop"
          "gimp.desktop"
        ];
        "image/gif" = [
          "imv.desktop"
          "sxiv.desktop"
          "gimp.desktop"
        ];
        "image/jpeg" = [
          "imv.desktop"
          "sxiv.desktop"
          "gimp.desktop"
        ];
        "image/jpg" = [
          "imv.desktop"
          "sxiv.desktop"
          "gimp.desktop"
        ];
        "image/pjpeg" = [
          "imv.desktop"
          "sxiv.desktop"
          "gimp.desktop"
        ];
        "image/png" = [
          "imv.desktop"
          "sxiv.desktop"
          "gimp.desktop"
        ];
        "image/tiff" = [
          "imv.desktop"
          "sxiv.desktop"
          "gimp.desktop"
        ];
        "image/x-bmp" = [
          "imv.desktop"
          "sxiv.desktop"
          "gimp.desktop"
        ];
        "image/x-pcx" = [
          "imv.desktop"
          "sxiv.desktop"
          "gimp.desktop"
        ];
        "image/x-png" = [
          "imv.desktop"
          "sxiv.desktop"
          "gimp.desktop"
        ];
        "image/x-portable-anymap" = [
          "imv.desktop"
          "sxiv.desktop"
          "gimp.desktop"
        ];
        "image/x-portable-bitmap" = [
          "imv.desktop"
          "sxiv.desktop"
          "gimp.desktop"
        ];
        "image/x-portable-graymap" = [
          "imv.desktop"
          "sxiv.desktop"
          "gimp.desktop"
        ];
        "image/x-portable-pixmap" = [
          "imv.desktop"
          "sxiv.desktop"
          "gimp.desktop"
        ];
        "image/x-tga" = [
          "imv.desktop"
          "sxiv.desktop"
          "gimp.desktop"
        ];
        "image/x-xbitmap" = [
          "imv.desktop"
          "sxiv.desktop"
          "gimp.desktop"
        ];
        "image/heif" = [
          "imv.desktop"
          "sxiv.desktop"
          "gimp.desktop"
        ];
      };
    };
    portal = {
      enable = prefs.enableXdgPortal;
      wlr.enable = prefs.enableXdgPortalWlr;
      # gtk portal needed to make gtk apps happy
      extraPortals = [ pkgs.xdg-desktop-portal-gtk ];
    };
  };

  users = builtins.foldl' (a: e: lib.recursiveUpdate a e) { } [
    (lib.optionalAttrs (!prefs.isVagrantBox) {
      users =
        let
          extraGroups = [
            "wheel"
            "cups"
            "video"
            "kvm"
            "libvirtd"
            "systemd-journal"
            "qemu-libvirtd"
            "audio"
            "sysdig"
            "disk"
            "keys"
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
        in
        {
          "${prefs.owner}" = {
            createHome = true;
            inherit extraGroups;
            group = prefs.ownerGroup;
            home = prefs.home;
            isNormalUser = true;
            uid = prefs.ownerUid;
            shell = if prefs.enableZSH then pkgs.zsh else pkgs.bash;
            initialHashedPassword = "$6$eE6pKPpxdZLueg$WHb./PjNICw7nYnPK8R4Vscu/Rw4l5Mk24/Gi4ijAsNP22LG9L471Ox..yUfFRy5feXtjvog9DM/jJl82VHuI1";
            openssh.authorizedKeys.keys = prefs.privilegedKeys;
          };
        };
      groups = {
        "${prefs.ownerGroup}" = {
          gid = prefs.ownerGroupGid;
        };
      };
    })
    {
      users = {
        root = {
          openssh.authorizedKeys.keys = prefs.privilegedKeys;
        };
      };
    }
    (lib.optionalAttrs prefs.enableKeyd {
      groups = {
        keyd = { };
      };
    })
    (lib.optionalAttrs prefs.enableFallbackAccount {
      users = {
        # Fallback user when "${prefs.owner}" encounters problems
        fallback = {
          group = "fallback";
          createHome = true;
          isNormalUser = true;
          useDefaultShell = true;
          initialHashedPassword = "$6$nstJFDdZZ$uENeWO2lup09Je7UzVlJpwPlU1SvLwzTrbm/Gr.4PUpkKUuGcNEFmUrfgotWF3HoofVrGg1ENW.uzTGT6kX3v1";
          openssh.authorizedKeys.keys = prefs.privilegedKeys;
        };
      };
      groups = {
        fallback = {
          name = "fallback";
        };
      };
    })
    (lib.optionalAttrs prefs.enableSshPortForwarding {
      users = {
        ssh-port-forwarding = {
          group = prefs.ownerGroup;
          createHome = true;
          isNormalUser = true;
          shell = "${pkgs.coreutils}/bin/echo";
          openssh.authorizedKeys.keys = prefs.privilegedKeys;
        };
      };
    })
  ];

  containers =
    let
      normalizeHostname = hostname: builtins.replaceStrings [ "_" ] [ "-" ] hostname;
    in
    {
      "wired-${normalizeHostname prefs.hostname}" = {
        privateNetwork = true;
        autoStart = prefs.enableContainerWired;
        extraFlags = [
          "--network-zone=wired"
        ];
        config = {
          services = {
            netbird = {
              enable = prefs.enableNetbird;
            };
          };
          systemd.network.enable = prefs.enableSystemdNetworkd;
          networking.useHostResolvConf = false;
          services.resolved.fallbackDns = [
            "223.6.6.6"
            "119.29.29.29"
          ];
          system.stateVersion = prefs.systemStateVersion;
        };
      };
    };

  virtualisation = {
    libvirtd = {
      enable = prefs.enableLibvirtd;
    };
    virtualbox.host = {
      # enable = prefs.enableVirtualboxHost;
      enableExtensionPack = prefs.enableVirtualboxHost;
      # enableHardening = false;
    };
    waydroid = {
      enable = prefs.enableWaydroid;
    };
    containerd = {
      enable = prefs.enableContainerd;
    };
    cri-o = {
      enable = prefs.enableCrio;
    };
    podman = {
      enable = prefs.enablePodman;
      dockerCompat = prefs.replaceDockerWithPodman;
      extraPackages = if (prefs.enableZfs) then [ pkgs.zfs ] else [ ];
    };
    docker = {
      enable = prefs.enableDocker && !prefs.replaceDockerWithPodman;
      extraOptions = builtins.concatStringsSep " " (
        [ "--experimental" ]
        ++ (lib.optionals prefs.enableDockerMetrics [
          "--metrics-addr=127.0.0.1:${builtins.toString prefs.dockerMetricsPort}"
        ])
      );
      autoPrune.enable = true;
    }
    // lib.optionalAttrs prefs.enableZfs {
      storageDriver = "zfs";
    };
  };

  # powerManagement = {
  #   enable = true;
  #   cpuFreqGovernor = "ondemand";
  # };

  systemd =
    let
      notify-systemd-unit-failures =
        let
          name = "notify-systemd-unit-failures";
        in
        {
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
    in
    (builtins.foldl' (a: e: lib.recursiveUpdate a e) { } [
      {
        settings.Manager = {
          DefaultLimitNOFILE = "8192:524288";
          DefaultTimeoutStopSec = "10s";
        };
        tmpfiles = {
          rules = [
            "d /root/.cache/trash - root root 30d"
            "d /root/.local/share/Trash - root root 30d"
            "d ${prefs.home}/.cache/trash - ${prefs.owner} ${prefs.ownerGroup} 30d"
            "d ${prefs.home}/.local/share/Trash - ${prefs.owner} ${prefs.ownerGroup} 30d"
          ]
          ++ [
            # This directory lies in /, which should never be snapshotted.
            # We use this directory to store large files as these files might never be deleted
            # if they are snapshotted. See also https://serverfault.com/questions/293009/zfs-removing-files-from-snapshots
            "d /nosnapshot/${prefs.owner} - ${prefs.owner} ${prefs.ownerGroup} -"
          ]
          ++ [
            "d /var/data/warehouse - ${prefs.owner} ${prefs.ownerGroup} -"
          ];
        };
      }

      {
        user = {
          extraConfig = ''
            # Disable memory accounting so that make systemd not to kill all processes in user session/scope.
            # https://github.com/systemd/systemd/issues/25376#issuecomment-1366931619
            DefaultMemoryAccounting=no
          '';
        };
      }

      # Failed to build protobuf, nodejs, llvm etc. Disable it for now.
      {
        oomd = {
          enable = false;
        };
      }

      {
        services =
          notify-systemd-unit-failures
          // (mergeOptionalConfigs [
            {
              enable = prefs.enableWstunnel;
              config = {
                # Copied from https://github.com/hmenke/nixos-modules/blob/da7bf05fd771373a8528dd00b97480c38d94c6de/modules/wstunnel/module.nix
                "wstunnel" = {
                  description = "wstunnel server";
                  before =
                    let
                      wg-quick = map (iface: "wg-quick-${iface}.service") (
                        lib.attrNames config.networking.wg-quick.interfaces
                      );
                      wireguard = lib.optionals config.networking.wireguard.enable (
                        map (iface: "wireguard-${iface}.service") (lib.attrNames config.networking.wireguard.interfaces)
                      );
                    in
                    wg-quick ++ wireguard;
                  after = [ "network.target" ];
                  wantedBy = [ "multi-user.target" ];
                  path = [ pkgs.wstunnel ];
                  serviceConfig = {
                    Restart = "always";
                    RestartSec = "1s";
                    # User
                    DynamicUser = true;
                    # Capabilities
                    AmbientCapabilities = [
                      "CAP_NET_RAW"
                      "CAP_NET_BIND_SERVICE"
                    ];
                    CapabilityBoundingSet = [
                      "CAP_NET_RAW"
                      "CAP_NET_BIND_SERVICE"
                    ];
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
                    RestrictAddressFamilies = [
                      "AF_UNIX"
                      "AF_INET"
                      "AF_INET6"
                    ];
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
                    exec wstunnel --verbose --server 127.0.0.1:${builtins.toString prefs.wstunnelPort}
                  '';
                };
              };
            }
            {
              enable = prefs.enableWireguard;
              config = (
                let
                  interfaces = builtins.attrNames config.networking.wg-quick.interfaces;
                in
                builtins.foldl' (
                  acc: e:
                  acc
                  // {
                    "wg-quick-${e}" = {
                      path = [
                        pkgs.gawk
                        pkgs.iptables
                        pkgs.bash
                        pkgs.gost
                      ];
                    };
                  }
                ) { } interfaces
              );
            }
            {
              enable = prefs.enableAvahi;
              config = {
                "avahi-daemon" = {
                  serviceConfig = {
                    # Avahi daemon seems to be not publishing  _workstation._tcp on start up.
                    # If it is the case, we try to restart it, because manually restarting it works.
                    Restart = "always";
                    ExecStartPost = "${pkgs.writeShellScript "maybe-restart-avahi" ''
                      for i in $(seq 1 4); do
                          if avahi-browse --parsable --resolve --terminate _workstation._tcp | grep ';127.0.0.1;'; then
                              exit 0
                          else
                              sleep "$i"
                          fi
                      done
                      exit 1
                    ''}";
                  };
                };
              };
            }
            {
              enable = (prefs.buildZerotierone && !prefs.enableZerotierone);
              config = {
                # build zero tier one anyway, but enable it on prefs.enableZerotierone is true;
                "zerotierone" = {
                  wantedBy = lib.mkForce [ ];
                };
              };
            }
            {
              enable = prefs.buildZerotierone;
              config = {
                "zerotierone" = {
                  serviceConfig = {
                    SupplementaryGroups = prefs.noproxyGroup;
                  };
                };
              };
            }
            {
              enable = prefs.enableSyncthing;
              config = {
                "syncthing" = {
                  serviceConfig = {
                    SupplementaryGroups = prefs.noproxyGroup;
                  };
                };
              };
            }
            {
              enable = prefs.enableTailScale;
              config = {
                "tailscaled" = {
                  serviceConfig = {
                    SupplementaryGroups = prefs.noproxyGroup;
                  };
                };
              };
            }
            {
              enable = config.virtualisation.docker.enable;
              config = {
                "docker" = {
                  serviceConfig = {
                    ExecStartPost = [
                      "${pkgs.procps}/bin/sysctl net.bridge.bridge-nf-call-iptables=0 net.bridge.bridge-nf-call-ip6tables=0 net.bridge.bridge-nf-call-arptables=0"
                    ];
                  };
                };
              };
            }
            {
              enable = prefs.enableCrio;
              config = {
                "crio" = {
                  path = with pkgs; [ conntrack-tools ] ++ (lib.optionals prefs.enableZfs [ zfs ]);
                };
              };
            }
            {
              enable = prefs.enableJupyter;
              config = {
                "jupyterhub" = {
                  path = with pkgs; [ nodejs_latest ];
                };
              };
            }
            {
              enable = prefs.enablePrometheus;
              config = {
                "prometheus" = {
                  serviceConfig = {
                    EnvironmentFile = "/run/secrets/prometheus-env";
                  };
                };
              };
            }
            {
              enable = prefs.enablePromtail;
              config = {
                "promtail" = {
                  serviceConfig = {
                    EnvironmentFile = "/run/secrets/promtail-env";
                  };
                };
              };
            }
            {
              enable = prefs.enableGrafana;
              config = {
                "grafana" = {
                  serviceConfig = {
                    EnvironmentFile = "/run/secrets/grafana-env";
                  };
                };
              };
            }
            {
              enable = prefs.enablePostgresql;
              config = {
                "postgresql" = {
                  serviceConfig = {
                    SupplementaryGroups = "keys";
                  };
                };
              };
            }
            {
              enable = prefs.enableMihomo;
              config = {
                mihomo = {
                  serviceConfig.ExecStartPre = [
                    "${pkgs.coreutils}/bin/ln -sf ${pkgs.v2ray-geoip}/share/v2ray/geoip.dat /var/lib/private/mihomo/GeoIP.dat"
                    "${pkgs.coreutils}/bin/ln -sf ${pkgs.v2ray-domain-list-community}/share/v2ray/geosite.dat /var/lib/private/mihomo/GeoSite.dat"
                  ];
                };
              };
            }
            {
              enable = (prefs.enableCodeServer);
              config = {
                "code-server" = {
                  enable = true;
                  description = "Remote VSCode Server";
                  after = [ "network.target" ];
                  wantedBy = [ "multi-user.target" ];
                  path = [
                    pkgs.go
                    pkgs.git
                    pkgs.direnv
                  ];
                  serviceConfig = {
                    Type = "simple";
                    ExecStart = "${pkgs.code-server}/bin/code-server --disable-telemetry --disable-update-check --user-data-dir ${prefs.home}/.vscode --extensions-dir ${prefs.home}/.vscode/extensions --bind-addr 127.0.0.1:4050 --auth password";
                    EnvironmentFile = "/run/secrets/code-server-env";
                    WorkingDirectory = prefs.home;
                    NoNewPrivileges = true;
                    User = prefs.owner;
                    Group = prefs.ownerGroup;
                  };
                };
              };
            }
          ]);
      }

      (
        let
          name = "syncoid-cleanup";
        in
        {
          services."${name}" = {
            enable = prefs.enableSyncoid;
            description = "Clean up syncoid snapshots";
            path = [
              pkgs.zfs
              pkgs.gawk
              pkgs.findutils
            ];
            requires = [ "local-fs.target" ];

            script = ''
              set -euo pipefail
              zfs list -t snapshot -s creation | awk '/@syncoid_${prefs.hostname}/ {print $1}' | head -n -20 | xargs --no-run-if-empty --verbose -n 1 zfs destroy
            '';
            serviceConfig = {
              Type = "oneshot";
            };
          };

          timers."${name}" = {
            enable = prefs.enableSyncoid;
            wantedBy = [ "default.target" ];
            after = [ "local-fs.target" ];
            timerConfig = {
              OnCalendar = "weekly";
              RandomizedDelaySec = 3600 * 12;
              Unit = "${name}.service";
            };
          };
        }
      )

      # For some currently unfathomable reason, wireless network periodically fails.
      (
        let
          name = "network-watchdog";
        in
        {
          services."${name}" = {
            description = "network watchdog";
            enable = prefs.enableNetworkWatchdog;
            wantedBy = [ "default.target" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            onFailure = [ "notify-systemd-unit-failures@${name}.service" ];
            path = [
              pkgs.coreutils
              pkgs.gawk
              pkgs.systemd
              pkgs.iputils
              pkgs.util-linux
            ]
            ++ lib.optionals prefs.enableIwd [ pkgs.iwd ];
            script = ''
              set -euo pipefail

              if ping -c3 _gateway; then
                  exit 0
              fi

              if systemctl is-active iwd && [[ -n "$(iwctl station list | awk '{if ($2 ~ /connected/) {print $1}}')" ]]; then
                  systemctl restart iwd
              fi
            '';
            serviceConfig = {
              Type = "oneshot";
              Restart = "on-failure";
            };
          };

          timers."${name}" = {
            enable = prefs.enableNetworkWatchdog;
            wantedBy = [ "default.target" ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            timerConfig = {
              RandomizedDelaySec = 60;
              OnCalendar = "*-*-* *:2/3:00";
              Unit = "${name}.service";
            };
          };
        }
      )

      {
        services = lib.optionalAttrs prefs.enableKeyd {
          keyd = {
            description = "key remapping daemon";
            wantedBy = [ "default.target" ];
            requires = [ "local-fs.target" ];
            after = [ "local-fs.target" ];
            serviceConfig = {
              Type = "simple";
              ExecStart = "${pkgs.keyd}/bin/keyd";
            };
          };
        };
      }

      {
        services = lib.optionalAttrs prefs.enableSingBox {
          sing-box = {
            serviceConfig = {
              ExecStartPre =
                let
                  script = pkgs.writeShellScript "sing-box-pre-start-bind-mount" ''
                    ${pkgs.coreutils}/bin/mkdir -p /run/sing-box
                    ${pkgs.coreutils}/bin/mkdir -p /etc/sing-box-config
                    ${pkgs.util-linux}/bin/mount --bind /etc/sing-box-config /run/sing-box
                  '';
                in
                lib.mkForce "+${script}";
            };
          };
        };
      }

      (
        let
          name = "rclone-webui";
        in
        {
          services.${name} = {
            description = "rclone web ui";
            enable = prefs.enableRcloneWebUI;
            onFailure = [ "notify-systemd-unit-failures@${name}.service" ];
            serviceConfig = {
              Restart = "always";
              # User
              LoadCredential = [
                "config:${config.sops.secrets.rclone-config.path}"
                "htpasswd:${config.sops.secrets.rclone-webui-htpasswd.path}"
              ];
              DynamicUser = true;
              # Capabilities
              AmbientCapabilities = [
                "CAP_NET_RAW"
                "CAP_NET_BIND_SERVICE"
              ];
              CapabilityBoundingSet = [
                "CAP_NET_RAW"
                "CAP_NET_BIND_SERVICE"
              ];
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
              RestrictAddressFamilies = [
                "AF_UNIX"
                "AF_INET"
                "AF_INET6"
              ];
              RestrictNamespaces = true;
              LockPersonality = true;
              MemoryDenyWriteExecute = true;
              RestrictRealtime = true;
              RestrictSUIDSGID = true;
              RemoveIPC = true;
              PrivateMounts = true;
              # System Call Filtering
              SystemCallArchitectures = "native";
              ExecStart = ''
                ${pkgs.rclone}/bin/rclone --config ''${CREDENTIALS_DIRECTORY}/config rcd --rc-web-gui --rc-web-gui-no-open-browser --rc-htpasswd ''${CREDENTIALS_DIRECTORY}/htpasswd
              '';
            };
          };
        }
      )

      # TODO: figure out why zerotier always goes offline
      (
        let
          name = "zerotierone";
          watchdogName = "${name}-watchdog";
        in
        lib.optionalAttrs prefs.buildZerotierone {
          services."${watchdogName}" = {
            description = "zerotierone watchdog";
            enable = true;
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            onFailure = [ "notify-systemd-unit-failures@${watchdogName}.service" ];
            path = with pkgs; [
              coreutils
              systemd
              zerotierone
            ];
            script = ''
              set -euo pipefail
              if ! systemctl is-active zerotierone; then
                  exit 0
              fi
              if zerotier-cli -p${builtins.toString config.services.zerotierone.port} info | grep -q -i offline; then
                  systemctl restart zerotierone
              fi
            '';
            serviceConfig = {
              Type = "oneshot";
            };
          };
          timers."${watchdogName}" = {
            enable = true;
            wantedBy = if prefs.enableZerotierone then [ "default.target" ] else [ ];
            after = [ "network-online.target" ];
            wants = [ "network-online.target" ];
            timerConfig = {
              RandomizedDelaySec = 2 * 60;
              OnCalendar = "*-*-* *:3/5:00";
              Unit = "${watchdogName}.service";
            };
          };
        }
      )
    ])
    // {
      user = builtins.foldl' (a: e: lib.recursiveUpdate a e) { } [
        { services = notify-systemd-unit-failures; }
        (
          let
            name = "ddns";
            unitName = "${name}@";
            script = pkgs.writeShellScript "ddns" ''
              set -euo pipefail
              host="''${DDNS_HOST:-$(hostname)}"
              if [[ -n "$1" ]] && [[ "$1" != "default" ]]; then host="$1"; fi
              base="$DDNS_BASE_DOMAIN"
              domain="$host.$base"
              password="$DDNS_PASSWORD"
              interfaces="$(ip link show up | awk -F'[ :]' '/MULTICAST/&&/LOWER_UP/ {print $3}')"
              ipAddr="$(parallel -k -r -v upnpc -m {1} -s ::: $interfaces 2>/dev/null | awk '/ExternalIPAddress/ {print $3}' | head -n1 || true)"
              if [[ -z "$ipAddr" ]]; then ipAddr="$(curl -sS myip.ipip.net | perl -pe 's/.*?([0-9]{1,3}.*[0-9]{1,3}?).*/\1/g')"; fi
              curl -sS "https://dyn.dns.he.net/nic/update?hostname=$domain&password=$password&myip=$ipAddr"
              ipv6Addr="$(ip -6 addr show scope global primary | grep -v mngtmpaddr | awk '/inet6/ {print $2}' | head -n1 | awk -F/ '{print $1}')"
              if [[ -n "$ipv6Addr" ]]; then curl -sS "https://dyn.dns.he.net/nic/update?hostname=$domain&password=$password&myip=$ipv6Addr"; fi
            '';
          in
          {
            services.${unitName} = {
              description = "ddns worker";
              enable = prefs.enableDdns;
              wantedBy = [ "default.target" ];
              onFailure = [ "notify-systemd-unit-failures@%i.service" ];
              path = [
                pkgs.coreutils
                pkgs.inetutils
                pkgs.parallel
                pkgs.miniupnpc
                pkgs.iproute2
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
              timerConfig = {
                OnCalendar = "*-*-* *:2/10:43";
                Unit = "${unitName}%i.service";
                Persistent = true;
              };
            };
          }
        )

        {
          services.nextcloud-client = {
            enable = prefs.enableNextcloudClient;
            description = "nextcloud client";
            wantedBy = [ "default.target" ];
            serviceConfig = {
              Restart = "always";
              EnvironmentFile = "%h/.config/Nextcloud/env";
            };
            path = [
              pkgs.nextcloud-client
              pkgs.inotify-tools
            ];
            script = ''
              mkdir -p "$HOME/$localFolder"
              while true; do
                    nextcloudcmd --non-interactive --silent --user "$user" --password "$password" "$localFolder" "$remoteUrl" || true
                    inotifywait -t 120 "$localFolder" > /dev/null 2>&1 || true
              done
            '';
          };
        }

        (
          let
            name = "hole-puncher";
            unitName = "${name}@";
            script = pkgs.writeShellScript "hole-puncher" ''
              set -euo pipefail
              instance="44443-${builtins.toString 44443}"
              if [[ -n "$1" ]] && grep -Eq '[0-9]+-[0-9]+' <<< "$1"; then instance="$1"; fi
              externalPort="$(awk -F- '{print $2}' <<< "$instance")"
              internalPort="$(awk -F- '{print $1}' <<< "$instance")"
              interfaces="$(ip link show up | awk -F'[ :]' '/MULTICAST/&&/LOWER_UP/ {print $3}' | grep -v veth)"
              ipAddresses="$(parallel -k ip addr show dev {1} ::: $interfaces | grep -Po 'inet \K[\d.]+')"
              protocols="tcp udp"
              result="$(parallel -r -v upnpc -m {1} -a {2} $internalPort $externalPort {3} ::: $interfaces :::+ $ipAddresses ::: $protocols || true)"
              awk -v OFS=, '/is redirected to/ {print $2, $8, $3}' <<< "$result"
            '';
          in
          {
            services.${unitName} = {
              description = "NAT traversal worker";
              enable = prefs.enableHolePuncher && prefs.enableSslh;
              wantedBy = [ "default.target" ];
              onFailure = [ "notify-systemd-unit-failures@${unitName}_%i.service" ];
              path = [
                pkgs.coreutils
                pkgs.parallel
                pkgs.miniupnpc
                pkgs.iproute2
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
              timerConfig = {
                OnCalendar = "*-*-* *:3/20:00";
                Unit = "${unitName}%i.service";
                Persistent = true;
              };
            };
          }
        )
        (
          let
            name = "task-warrior-sync";
          in
          {
            services.${name} = {
              description = "sync task warrior tasks";
              enable = prefs.enableTaskWarriorSync;
              onFailure = [ "notify-systemd-unit-failures@${name}.service" ];
              serviceConfig = {
                Type = "oneshot";
                ExecStart = "${pkgs.taskwarrior3}/bin/task synchronize";
              };
            };
            timers.${name} = {
              enable = prefs.enableTaskWarriorSync;
              wantedBy = [ "default.target" ];
              timerConfig = {
                OnCalendar = "*-*-* *:1/3:00";
                Unit = "${name}.service";
                Persistent = true;
              };
            };
          }
        )

        (
          let
            name = "vdirsyncer";
          in
          {
            services.${name} = {
              description = "vdirsyncer sync";
              enable = prefs.enableTaskWarriorSync;
              onFailure = [ "notify-systemd-unit-failures@${name}.service" ];
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
              wantedBy = [ "default.target" ];
              timerConfig = {
                OnCalendar = "*-*-* *:1/3:00";
                Unit = "${name}.service";
                Persistent = true;
              };
            };
          }
        )

        (
          let
            name = "yandex-disk";
          in
          if prefs.enableYandexDisk then
            {
              services.${name} = {
                enable = true;
                description = "Yandex-disk server";
                onFailure = [ "notify-systemd-unit-failures@%i.service" ];
                after = [ "network-online.target" ];
                wants = [ "network-online.target" ];
                wantedBy = [ "default.target" ];
                unitConfig.RequiresMountsFor = prefs.syncFolder;
                serviceConfig = {
                  Restart = "always";
                  ExecStart = "${pkgs.yandex-disk}/bin/yandex-disk start --no-daemon --auth=/run/secrets/yandex-passwd --dir='${prefs.syncFolder}' ${
                    lib.concatMapStringsSep " " (dir: "--exclude-dirs='${dir}'") prefs.yandexExcludedDirs
                  }";
                };
              };
            }
          else
            { }
        )
      ];
    };

  nix = {
    inherit (prefs) buildMachines distributedBuilds;
    package = pkgs.nixVersions.stable;
    extraOptions = "experimental-features = nix-command flakes";
    settings = {
      sandbox = true;
      trusted-users = [
        "root"
        prefs.owner
        "@wheel"
      ];
      max-jobs = prefs.maxJobs;
      builders-use-substitutes = true;
      build-cores = prefs.buildCores;
      binary-caches = [ "https://mirrors.tuna.tsinghua.edu.cn/nix-channels/store" ];
      binary-cache-public-keys = [ ];
      auto-optimise-store = true;
      substituters = if config.hardware.nvidia.enabled then [ "https://cache.nixos-cuda.org" ] else [ ];
      trusted-public-keys =
        if config.hardware.nvidia.enabled then
          [ "cache.nixos-cuda.org:74DUi4Ye579gUqzH4ziL9IyiJBlDpMRn9MBN8oNan9M=" ]
        else
          [ ];
    };
    gc = {
      automatic = true;
      # Aoid auto gc on startup.
      # Sometimes I try to build something unsuccessfully, and
      # nix gced the partial result. This is undesirable.
      # Note this effectively means that auto gc will never run,
      # I keep my machine running in the evening.
      dates = "2:15";
      persistent = false;
      randomizedDelaySec = "1h";
      options = "--delete-older-than 60d";
    };
    optimise = {
      automatic = true;
      # It is better that optimise comes after gc.
      dates = [ "3:45" ];
    };
    nixPath = [ "/etc/nix/path" ];

    registry.nixpkgs.flake = inputs.nixpkgs;
    registry.nixpkgs-stable.flake = inputs.nixpkgs-stable;
    registry.nixpkgs-unstable.flake = inputs.nixpkgs-unstable;
    registry.home-manager.flake = inputs.home-manager;
    registry.activeconfig.flake = inputs.self;
    registry.config.to = {
      type = "path";
      path = "${prefs.home}/Workspace/infra";
    };
  };

  boot = {
    binfmt = { inherit (prefs) emulatedSystems; };
    kernel.sysctl = prefs.kernelSysctl;
    loader = {
      generationsDir = {
        enable = prefs.enableGenerationsDir;
        copyKernels = true;
      };
      efi = {
        canTouchEfiVariables = prefs.efiCanTouchEfiVariables;
      };
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
    };

    supportedFilesystems = if (prefs.enableZfs) then [ "zfs" ] else [ ];
    zfs = {
      package = lib.mkIf prefs.enableZfsUnstable pkgs.zfs_unstable;
    };
    crashDump = {
      enable = prefs.enableCrashDump;
    };
    initrd = {
      kernelModules = prefs.initrdKernelModules;
      availableKernelModules = prefs.initrdAvailableKernelModules;
      secrets = {
        "/bin/hole-puncher" = config.sops.secrets.initrd-hole-puncher.path;
        "/root/.ssh/id_ed25519" = config.sops.secrets."port-forwarding-id_ed25519".path;
        "/root/.ssh/id_ed25519.pub" = config.sops.secrets."port-forwarding-id_ed25519.pub".path;
      };
      network = {
        enable = true;
        ssh =
          let
            f = impure.sshAuthorizedKeys;
            authorizedKeys =
              prefs.authorizedKeys
              ++ (lib.optionals (builtins.pathExists f) (
                builtins.filter (x: x != "") (pkgs.lib.splitString "\n" (builtins.readFile f))
              ));
            hostKeys = builtins.filter (x: builtins.pathExists x) [ /run/secrets/initrd_ssh_host_ed25519_key ];
          in
          {
            inherit authorizedKeys hostKeys;
            enable = prefs.enableBootSSH && authorizedKeys != [ ] && hostKeys != [ ];
          };
      };
    };
  }
  # microvm use its own kernel config.
  // lib.optionalAttrs (!prefs.enableMicrovmGuest) {
    inherit (prefs)
      kernelParams
      extraModulePackages
      kernelModules
      kernelPatches
      kernelPackages
      blacklistedKernelModules
      ;
  };
}
