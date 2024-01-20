{ config, pkgs, lib, options, prefs, inputs, ... }@args:
let
  brokenPackages =
    let p = ./broken-packages.nix;
    in if builtins.pathExists p then (import p) else [ ];
  linuxOnlyPackages = [ "kdeconnect" ];
  x86OnlyPackages =
    let
      brokenOnArmPackages =
        [ "eclipses.eclipse-java" "hardinfo" "ltrace" "brave" "mplayer" ];
    in
    brokenOnArmPackages ++ [
      "wine"
      "workrave"
      "lens"
      "android-file-transfer"
      "androidenv.androidPkgs_9_0.platform-tools"
      "appimage-run"
      "adbfs-rootless"
      "mitscheme"
      "simplescreenrecorder"
      "syslinux"
      "gitAndTools.git-annex"
      "myPackages.python"
      "myPackages.ghc"
      "vivaldi"
      "libpng"
      "cachix"
      "git-annex"
      "texlab"
    ];
  largePackages = [
    "jetbrains.idea-ultimate"
    "jetbrains.clion"
    "jetbrains.webstorm"
    "jetbrains.datagrip"
    "jetbrains.goland"
    "jetbrains.pycharm-professional"
    "kubernetes"
    "minikube"
    "k3s"
    "brave"
    "flink"
    "myPackages.ghc"
    "libguestfs-with-appliance"
    "androidStudioPackages.dev"
    "confluent-platform"
    "qemu"
    "tdesktop"
    "jitsi-meet-electron"
    "llvmPackages_latest.clang"
    "llvmPackages_latest.lld"
    "llvmPackages_latest.lldb"
    "clang-analyzer"
    "racket"
    "ocaml"
    "llvmPackages_latest.llvm"
    "termonad"
    "steam"
    "espeak"
    "vagrant"
    "firecracker"
    "code-server"
    "eclipses.eclipse-java"
    "myPackages.texLive"
    "clojure-lsp"
    "clojure"
    "coursier"
    "leiningen"
    "ammonite"
    "joplin"
    "joplin-desktop"
    "texmacs"
    # "qute-browser"
    "vscodium"
    # "krita"
    "xmind"
  ];
  # To avoid clash within the buildEnv of home-manager
  overridePkg = pkg: func:
    if pkg ? overrideAttrs then
      pkg.overrideAttrs (oldAttrs: func oldAttrs)
    else pkg;
  changePkgPriority = pkg: priority:
    overridePkg pkg (oldAttrs: { meta = { priority = priority; }; });
  getAttr = attrset: path:
    builtins.foldl'
      (acc: x:
        if acc ? ${x} then
          acc.${x}
        else
          lib.warn "Package ${path} does not exists" null)
      attrset
      (pkgs.lib.splitString "." path);
  getMyPkg = attrset: path:
    let
      pkg =
        let
          vanillaPackage = getAttr attrset path;
          tryNewPath = newPath:
            if (newPath == path) then
              null
            else
              lib.warn "Package ${path} does not exists, trying ${newPath}"
                (getAttr attrset newPath);
          nixpkgsPackage =
            tryNewPath (builtins.replaceStrings [ "myPackages." ] [ "" ] path);
          unstablePackage = tryNewPath "unstable.${path}";
        in
        if vanillaPackage != null then
          vanillaPackage
        else if nixpkgsPackage != null then
          nixpkgsPackage
        else if unstablePackage != null then
          unstablePackage
        else
          lib.warn "${path} not found" null;

      # Sometimes packages failed to build. We use this to skip running tests.
      # Don't use this on normal packages, otherwise we won't be able to downlaod caches from binary caches.
      dontCheck = false;
    in
    if dontCheck
    then
      overridePkg
        pkg
        (oldAttrs: {
          # Fuck, why every package has broken tests? I just want to trust the devil.
          # Fuck, this does not seem to work.
          doCheck = false;
        })
    else
      pkg;

  # Emits a warning when package does not exist, instead of quitting immediately
  getPkg = attrset: path:
    if prefs.hostname == "broken-packages" then
      (if !builtins.elem path brokenPackages then
        getMyPkg attrset path
      else
        lib.warn
          "${path} is will not be installed on a broken packages systems (hostname broken-packages)"
          null)
    else if builtins.elem path brokenPackages then
      lib.warn "${path} will not be installed as it is marked as broken" null
    else if !prefs.useLargePackages && (builtins.elem path largePackages) then
      lib.info "${path} will not be installed as useLargePackages is ${
        lib.boolToString prefs.useLargePackages
      }"
        null
    else if !(builtins.elem prefs.nixosSystem [ "x86_64-linux" "aarch64-linux" ])
      && (builtins.elem path linuxOnlyPackages) then
      lib.info "${path} will not be installed in system ${prefs.nixosSystem}"
        null
    else if !(builtins.elem prefs.nixosSystem [ "x86_64-linux" ])
      && (builtins.elem path x86OnlyPackages) then
      lib.info "${path} will not be installed in system ${prefs.nixosSystem}"
        null
    else
      getMyPkg attrset path;

  getPackages = list:
    (builtins.filter (x: x != null) (builtins.map (x: getPkg pkgs x) list));
  allPackages = builtins.foldl'
    (acc: collection:
      acc ++ (builtins.map (pkg: changePkgPriority pkg collection.priority)
        collection.packages)) [ ]
    (if prefs.installHomePackages then packageCollection else [ ]);
  packageCollection = [
    {
      name = "command line tools (preferred)";
      priority = 48;
      packages = getPackages [ "parallel" ];
    }
    {
      name = "command line tools (unstable)";
      priority = 48;
      packages = getPackages [ ];
    }
    {
      name = "command line tools";
      priority = 50;
      packages = getPackages [
        "bash-completion"
        "zsh-completions"
        "nushell"
        "fish"
        "sdcv"
        "ranger"
        "rename"
        "ripgrep"
        "file"
        "ack"
        "patch"
        # "doxygen"
        # "libxslt"
        # "xmlto"
        "moreutils"
        "nnn"
        "glib"
        "broot"
        "navi"
        "ncdu"
        "links2"
        "curl"
        "unrar"
        "bzip2"
        "mc"
        "most"
        "pstree"
        "yaft"
        "st"
        "ltrace"
        "strace"
        "uftrace"
        "mtr"
        "lynx"
        "elinks"
        "wget"
        "w3m-full"
        "ueberzug"
        "wgetpaste"
        "ix"
        "tmux"
        "zellij"
        "traceroute"
        "tree"
        # sl
        "fbterm"
        "fortune"
        "fpp"
        "fzf"
      ];
    }
    {
      name = "development tools (more preferred)";
      priority = 38;
      packages = getPackages [
        # "myPackages.python"
      ];
    }
    {
      name = "development tools (preferred)";
      priority = 39;
      packages = getPackages [
        "gdb"
        "gcc"
        # "glibc"
        "vscodium"
        "dotty"
        "stdman"
        # "hadoop_3_1"
        # "kubernetes"
        "gnumake"
        "gitAndTools.git-sync"
        # "opencl-headers"
      ];
    }
    {
      name = "development tools";
      priority = 40;
      packages = getPackages [
        "gnumake"
        "cmake"
        "meson"
        "ninja"
        "bear"
        "rustup"
        "gopls"
        "nil"
        "pyright"
        "cargo-edit"
        "cargo-xbuild"
        "cargo-update"
        "cargo-generate"
        "racket"
        "myPackages.ruby"
        "zeal"
        "vagrant"
        "shellcheck"
        # "zig"
        "stdmanpages"
        "astyle"
        "caddy"
        "flyway"
        # "myPackages.idris"
        # "myPackages.agda"
        # "myPackages.elba"
        "protobuf"
        # "capnproto"
        "gflags"
        "chezmoi"
        "direnv"
        "bubblewrap"
        "firejail"
        "rdbtools"
        "meld"
        "ccache"
        # "llvmPackages_latest.clang"
        # "llvmPackages_latest.lld"
        # > warning: creating dangling symlink `/nix/store/mip5hldyn294yn3lbl9ai2wyfjay9mm4-home-manager-path//lib/python3.9/site-packages/lldb/lldb-argdumper' -> `/nix/store/1s0zx2inw572iz5rh3cyjmg4q64vdrmv-lldb-12.0.1/lib/python3.9/site-packages/lldb/lldb-argdumper' -> `../../../../../../../build/lldb-12.0.1.src/build/bin/lldb-argdumper'
        # > warning: creating dangling symlink `/nix/store/mip5hldyn294yn3lbl9ai2wyfjay9mm4-home-manager-path//lib/python3.9/site-packages/lldb/_lldb.so' -> `/nix/store/1s0zx2inw572iz5rh3cyjmg4q64vdrmv-lldb-12.0.1/lib/python3.9/site-packages/lldb/_lldb.so' -> `../../../liblldb.so'
        # > error: collision between `/nix/store/n1jsmd24bgl1k8d68plmr8zpj8kc7pdq-lldb-12.0.1-lib/lib/python3.9/site-packages/lldb/_lldb.so' and dangling symlink `/nix/store/1s0zx2inw572iz5rh3cyjmg4q64vdrmv-lldb-12.0.1/lib/python3.9/site-packages/lldb/_lldb.so'
        # "llvmPackages_latest.lldb"
        # "llvmPackages_latest.llvm"
        "clang-tools"
        "clang-analyzer"
        # "xmlstarlet"
        "nasm"
        "go"
        "sqlitebrowser"
        "sqlite"
        "mitscheme"
        "guile"
        "emacs"
        "myPackages.magit"
        "mu"
        "yq-go"
        "dhall"
        "rlwrap"
        "git-revise"
        "git-crypt"
        "gitAndTools.gitFull"
        "gitAndTools.lfs"
        "gitAndTools.git-absorb"
        "gitAndTools.hub"
        "gitAndTools.gh"
        "gitAndTools.lab"
        "gitAndTools.tig"
        "gitAndTools.pre-commit"
        "gitAndTools.git-extras"
        "gitAndTools.git-hub"
        "gitAndTools.git-annex"
        "gitAndTools.git-subrepo"
        "gitAndTools.diff-so-fancy"
        "b4"
        "vscode"
        "wakatime"
        "ostree"
        # "postman"
        # "jetbrains.idea-ultimate"
        # "jetbrains.clion"
        # "jetbrains.webstorm"
        # "jetbrains.datagrip"
        # "jetbrains.goland"
        # "jetbrains.pycharm-professional"
        # "androidStudioPackages.dev"
        "go2nix"
        "gnum4"
        "clinfo"
        "ocl-icd"
        # "cudatoolkit"
        "syslinux"
        "rr"
        "gdbgui"
        # "pwndbg"
        "valgrind"
        "wabt"
        "hexyl"
        "fd"
        "trash-cli"
        "bat"
        "delta"
        "difftastic"
        "hyperfine"
        "procs"
        "pastel"
        "tokei"
        "starship"
        "atuin"
        # "watchexec"
        "zoxide"
        "kmon"
        "bandwhich"
        "grex"
        "bingrep"
        "xxd"
        "bless"
        "dhex"
        "yj"
        "eza"
        "delve"
        "pkg-config"
        "autoconf"
        "libtool"
        "autogen"
        "geany"
        "cdrkit"
        "gettext"
        "glances"
        "distcc"
        "remake"
        "cntr"
        "docker"
        "docker-compose"
        "buildkit"
        "python3Packages.binwalk"
        "python3Packages.xdot"
        "binutils"
        "bison"
        "tealdeer"
        "cht-sh"
        "automake"
        "assh"
        "autossh"
        "ssh-import-id"
        # "openssh"
        "myPackages.ssh"
        "myPackages.mosh"
        "myPackages.ssho"
        "myPackages.mosho"
        "eternal-terminal"
        "sshpass"
        # "dfeet"
        "axel"
        "neovim-remote"
        "androidenv.androidPkgs_9_0.platform-tools"
        "colordiff"
        "jq"
        "jless"
        "rq"
        "coq"
        "bundix"
        "buildah"
        "ansible"
        "vite"
        "solargraph"
        "tree-sitter"
        "sumneko-lua-language-server"
        "luaformatter"
        "nodePackages.dockerfile-language-server-nodejs"
        "nodePackages.bash-language-server"
        "nodePackages.typescript-language-server"
        "sqlint"
        "sbt-extras"
        # "clojure-lsp"
        # "julia"
        # "graalvm8"
        "metals"
        "omnisharp-roslyn"
        "so"
        # "myPackages.almond"
        # "myPackages.jupyter"
        "shfmt"
        "pkg-config"
        # "gcc.cc.lib"
        "readline"
        "zlib"
        # "cryptopp"
        "stress-ng"
        "expat"
        "mkcert"
      ];
    }
    {
      name = "multimedia";
      priority = 60;
      packages = getPackages [
        "gifsicle"
        # "gimp"
        "ncpamixer"
        "maim"
        # "pavucontrol"
        "exiftool"
        "flac"
        "mpc_cli"
        "ncmpcpp"
        "shntool"
        "sox"
        "pamixer"
        "imv"
        "cmus"
        "radiotray-ng"
        # "rhythmbox"
        "mplayer"
        "yewtube"
        "mpv"
        # "python3Packages.subliminal"
        "sxiv"
        # "vlc"
        "pyradio"
        "mpd"
        "exiv2"
      ];
    }
    {
      name = "network tools (preferred)";
      priority = 24;
      packages = getPackages [ ];
    }
    {
      name = "network tools";
      priority = 25;
      packages = getPackages [
        "httpie"
        "xh"
        # "wireshark"
        "termshark"
        "nmap"
        "masscan"
        "zmap"
        "slirp4netns"
        # "squid"
        "proxychains"
        "speedtest-cli"
        "privoxy"
        "badvpn"
        "connect"
        "conntrack-tools"
        "tor"
        # "resilio-sync"
        "iperf"
        "gperf"
        "mitmproxy"
        "ettercap"
        "redsocks"
        "wget"
        "ipget"
        "asciidoctor"
        "you-get"
        "uget"
        "udptunnel"
        "wireguard-tools"
        "gomuks"
        "irssi"
        # "chromium"
        "ungoogle-chromium"
        "brave"
        "aria2"
        "tinc"
        "tcpdump"
        "geoipWithDatabase"
        "syncthing"
        # "myPackages.wallabag-client"
        "gupnp-tools"
        "strongswan"
        "stunnel"
        "shadowsocks-libev"
        "gost"
        "v2ray"
        "clash-meta"
        "simplescreenrecorder"
        "slop"
        "smartmontools"
        "soapui"
        "inetutils"
        "socat"
        "neomutt"
        "thunderbird"
        "mu"
        "vivaldi"
        "firefox"
        "tridactyl-native"
        "brotab"
        "buku"
        "sshuttle"
        "youtube-dl"
        "offlineimap"
      ];
    }
    {
      name = "system (preferred)";
      priority = 18;
      packages = getPackages [
        "e2fsprogs"
      ];
    }
    {
      name = "system";
      priority = 20;
      packages = getPackages [
        # "myPackages.nur-combined.repos.kalbasit.nixify"
        "udiskie"
        "acpi"
        "wine"
        "winetricks"
        "usbutils"
        "nethogs"
        "powertop"
        "fail2ban"
        "udisks"
        "samba"
        "nixpkgs-review"
        "nix-prefetch-scripts"
        "nix-prefetch-github"
        "nix-universal-prefetch"
        "pulsemixer"
        "pavucontrol"
        "pciutils"
        "ntfs3g"
        "parted"
        "mtools"
        "gnupg"
        "gptfdisk"
        "at"
        "git"
        "gitRepo"
        "coreutils-prefixed"
        "notify-osd"
        "sxhkd"
        "mimeo"
        "libsecret"
        "libsystemtap"
        "gnome3.gnome-keyring"
        "gnome3.libgnome-keyring"
        "gnome3.seahorse"
        "mlocate"
        "htop"
        "bottom"
        "iotop"
        "inotifyTools"
        "noti"
        "ntfy"
        "apprise"
        "barrier"
        "gnutls"
        "iw"
        "lsof"
        "hardinfo"
        "dmenu"
        "dmidecode"
        "bind"
        "ldns"
        "bridge-utils"
        "dnstracer"
        # doublecmd-gtk2
        "dstat"
        "dunst"
        "f2fs-tools"
        "codeblocks"
        "efibootmgr"
        "linuxHeaders"
        "cryptsetup"
        "picom"
        "btrbk"
        "exfat"
      ];
    }
    {
      name = "document";
      priority = 45;
      packages = getPackages [
        "bibtool"
        "pdf2djvu"
        # "calibre"
        "ebook_tools"
        "coolreader"
        "proselint"
        "myPackages.hunspell"
        "myPackages.aspell"
        "pdfgrep"
        "gnumeric"
        "texlab"
        # "mupdf"
        "graphviz"
        # "logseq"
        "gnuplot"
        "goldendict"
        "zathura"
        # "sioyek"
        "qpdfview"
        "koreader"
        "abiword"
        "zile"
        "freemind"
        "xmind"
        "zotero"
        "stable.papis"
        # "k2pdfopt"
        # "beamerpresenter"
        "pdftk"
        # "jfbview"
        # "jfbpdf"
        "djvulibre"
        "djvu2pdf"
      ];
    }
    {
      name = "utilities (preferred)";
      priority = 34;
      packages = getPackages [ "elfutils" ];
    }
    {
      name = "utilities";
      priority = 35;
      packages = getPackages [
        "aha"
        "lzma"
        "libuchardet"
        "recode"
        "maim"
        "mtpaint"
        "unison"
        "unionfs-fuse"
        "p7zip"
        "xarchiver"
        "lz4"
        "zip"
        "xclip"
        "kdeconnect"
        "localsend"
        "adbfs-rootless"
        "asciinema"
        "pcmanfm"
        "xfce.thunar"
        "android-file-transfer"
        "qalculate-gtk"
        "bc"
        "go-2fa"
        "tectonic"
        "patchelf"
        "libelf"
        "libusb"
        "cachix"
        "barcode"
        "bitlbee"
        "blueberry"
        "calcurse"
        "castget"
        "xfce.catfish"
        # ccat
        # cfv
        "cheat"
        # cower
        "davfs2"
        # d-feet
        "dialog"
        # dictd
        "diffutils"
        # emms
        "entr"
        "evtest"
        "xfce.exo"
        "xorg.xwd"
        "fakeroot"
        # fbgrab
        "fbida"
        "fbv"
        "fdupes"
        "figlet"
        # finch
        "findutils"
        "flex"
        # gaupol
        "groff"
        "gv"
        "gvfs"
        "bindfs"
        "proot"
        "hamster"
        "hashdeep"
        "haveged"
        "hdparm"
        "hwinfo"
        "lshw"
        "icdiff"
        "iftop"
        "flamegraph"
        "inferno"
        "pprof"
        "ifuse"
        "inetutils"
        "iputils"
        "jp2a"
        "krop"
        "libgnome-keyring3"
        "libinput"
        "libinput-gestures"
        "lolcat"
        "copyq"
        "rbw"
        "keepassxc"
        "mkpasswd"
        "scrot"
        "flameshot"
        "mcabber"
        "mdadm"
        # "mongodb"
        "mujs"
        "multitail"
        # "myPackages.helix"
        "helix"
        "neovim"
        "neovide"
        "rnix-lsp"
        "ntp"
        "pastebinit"
        # "peek"
        "plan9port"
        "pngquant"
        "procps"
        "psmisc"
        "pv"
        "pwgen"
        "pwsafe"
        "qdirstat"
        "qpdf"
        "qrencode"
        "zbar"
        "rmlint"
        "rofi"
        "rsibreak"
        # "scite"
        "screenkey"
        # seahorse
        "speedcrunch"
        "ssh-to-pgp"
        "x11vnc"
        "tigervnc"
        "wayvnc"
        # "remmina"
        "rsync"
        "rclone"
        "restic"
        "fuse-overlayfs"
        "gnutar"
        "zstd"
        "gzip"
        "gnugrep"
        "gnused"
        "sd"
        "gawk"
        "dos2unix"
        "subdl"
        "espeak"
        "synapse"
        "sysfsutils"
        "sysstat"
        "tabbed"
        "vit"
        "dstask"
        "tcl"
        "tcllib"
        "foot"
        "wezterm"
        "texinfo"
        "thefuck"
        "tk"
        "tlp"
        # "unoconv"
        "unzip"
        "urlscan"
        "viewnior"
        "watson"
        "workrave"
      ];
    }
  ];
in
{
  programs = {
    direnv = {
      enable = true;
      nix-direnv.enable = true;
    };
  };
  # programs = lib.optionalAttrs (prefs.enableSmos) {
  #   smos = {
  #     enable = true;
  #     config = { workflow-dir = "${prefs.syncFolder}/workflow"; };
  #     # TODO: I use a custom systemd unit instead of this, as it is more secure.
  #     sync = {
  #       enable = false;
  #       # Note we must change the password here.
  #       username = "YOURUSERNAMEHERE";
  #       password = "YOURPASSWORDHERE";
  #       server-url = "https://smos.hub.${prefs.mainDomain}";
  #     };
  #     backup = { enable = true; };
  #     notify = { enable = true; };
  #   };
  # };

  services = {
    kdeconnect = { enable = prefs.enableKdeConnect; };
    syncthing = { enable = prefs.enableHomeManagerSyncthing; };
  };

  systemd.user =
    let
      # Copied from https://github.com/NixOS/nixpkgs/blob/634141959076a8ab69ca2cca0f266852256d79ee/nixos/modules/services/editors/emacs.nix#L91
      # set-environment is needed for some environment variables.
      # We use /etc/set-environment as the config config.system.build.setEnvironment is nixos config, not home-manager config.
      importEnvironmentForCommand = command:
        let
          script = pkgs.writeShellApplication
            {
              name = "import-environment";
              text = ''
                if [[ -f /etc/set-environment ]]; then
                    # shellcheck disable=SC1091
                    source /etc/set-environment;
                fi
                exec "$@"
              '';
            };
        in
        "${script} ${command}";
    in
    builtins.foldl' (a: e: lib.recursiveUpdate a e) { } [
      # (
      #   let name = "smos-sync";
      #   in
      #   lib.optionalAttrs prefs.enableSmosSync {
      #     services.${name} = {
      #       Unit = { Description = "sync smos"; };
      #       Service = {
      #         Type = "oneshot";
      #         ExecStart =
      #           "${(config.programs.smos.smosReleasePackages or config.programs.smos.smosPackages).smos-sync-client}/bin/smos-sync-client sync";
      #         EnvironmentFile = "/run/secrets/smos-sync-env";
      #       };
      #     };
      #     timers.${name} = {
      #       Unit = { OnFailure = [ "notify-systemd-unit-failures@%i.service" ]; };
      #       Install = { WantedBy = [ "default.target" ]; };
      #       Timer = {
      #         OnCalendar = "*-*-* *:1/3:00";
      #         Unit = "${name}.service";
      #         Persistent = true;
      #       };
      #     };
      #   }
      # )

      (
        let name = "foot";
        in
        lib.optionalAttrs prefs.enableFoot {
          services.${name} = {
            Unit = { Description = "foot server"; };
            Install = { WantedBy = [ "default.target" ]; };
            Service = {
              Type = "simple";
              Restart = "always";
              ExecStart = importEnvironmentForCommand "${pkgs.foot}/bin/foot --server";
            };
          };
        }
      )
    ];

  home = {
    extraOutputsToInstall = prefs.extraOutputsToInstall;
    packages = allPackages;
    stateVersion = prefs.homeManagerStateVersion;
  };

  xdg.dataFile = {
    "nix/path/nixpkgs".source = inputs.nixpkgs;
    "nix/path/nixpkgs-stable".source = inputs.nixpkgs-stable;
    "nix/path/nixpkgs-unstable".source = inputs.nixpkgs-unstable;
    "nix/path/home-manager".source = inputs.home-manager;
    "nix/path/activeconfig".source = inputs.self;
  } // lib.optionalAttrs (builtins.pathExists "${prefs.home}/Workspace/infra") {
    "nix/path/config".source = "${prefs.home}/Workspace/infra";
    "nix/path/infra".source = "${prefs.home}/Workspace/infra";
  };
}
