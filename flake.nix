{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.05";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-24.05";
    home-manager.url = "github:nix-community/home-manager/release-24.05";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    flake-utils.url = "github:numtide/flake-utils";

    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
    # Waiting for https://github.com/edolstra/flake-compat/pull/26
    flake-compat-result = {
      url = "github:teto/flake-compat/8e15c6e3c0f15d0687a2ab6ae92cc7fab896bfed";
      flake = false;
    };

    nixpkgs-wayland = { url = "github:nix-community/nixpkgs-wayland"; };
    nixpkgs-wayland.inputs.nixpkgs.follows = "nixpkgs";

    nix-alien = {
      url = "github:thiagokokada/nix-alien";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };

    nix-autobahn.url = "github:Lassulus/nix-autobahn";
    nix-autobahn.inputs.nixpkgs.follows = "nixpkgs";
    nix-autobahn.inputs.flake-utils.follows = "flake-utils";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.inputs.utils.follows = "flake-utils";
    deploy-rs.inputs.flake-compat.follows = "flake-compat";

    gomod2nix.url = "github:tweag/gomod2nix";
    gomod2nix.inputs.nixpkgs.follows = "nixpkgs";

    aioproxy.url = "github:contrun/aioproxy";
    aioproxy.inputs.nixpkgs.follows = "nixpkgs";
    aioproxy.inputs.gomod2nix.follows = "gomod2nix";
    aioproxy.inputs.flake-utils.follows = "flake-utils";

    android-nixpkgs = {
      url = "github:tadfisher/android-nixpkgs/stable";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nix-on-droid.url = "github:t184256/nix-on-droid";
    nix-on-droid.inputs.nixpkgs.follows = "nixpkgs";
    nix-on-droid.inputs.home-manager.follows = "home-manager";

    microvm.url = "github:astro/microvm.nix";
    microvm.inputs.nixpkgs.follows = "nixpkgs";
    microvm.inputs.flake-utils.follows = "flake-utils";

    nixos-generators = {
      url = "github:nix-community/nixos-generators";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    nur-no-pkgs.url = "github:nix-community/NUR";

    wallabag-client = {
      url = "github:artur-shaik/wallabag-client";
      flake = false;
    };

    authinfo = {
      url = "github:aartamonau/authinfo";
      flake = false;
    };

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    emacs-overlay.url = "github:nix-community/emacs-overlay";

    flake-firefox-nightly.url = "github:colemickens/flake-firefox-nightly";
    flake-firefox-nightly.inputs.nixpkgs.follows = "nixpkgs";

    nixpkgs-mozilla = {
      url = "github:mozilla/nixpkgs-mozilla";
      flake = false;
    };

    smos = {
      url = "github:NorfairKing/smos";
    };

    old-ghc-nix = {
      url = "github:mpickering/old-ghc-nix";
      flake = false;
    };

    dotfiles.url = "github:contrun/dotfiles";

    jtojnar-nixfiles = {
      url = "github:jtojnar/nixfiles";
      inputs = {
        home-manager.follows = "home-manager";
        flake-compat.follows = "flake-compat";
      };
    };

    nixos-vscode-server = {
      url = "github:msteen/nixos-vscode-server";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, flake-utils, gomod2nix, nix-alien, nix-on-droid, ... }@inputs:
    let
      lib = nixpkgs.lib;

      getConfig = path: ./. + "/${path}";

      getNixConfig = path: getConfig "nix/${path}";

      getHostPreference = hostname:
        let
          old = ((import (getNixConfig "prefs.nix")) {
            inherit hostname inputs;
          }).pure;
        in
        old // { system = old.nixosSystem; };

      generateHostConfigurations = hostname: inputs:
        let prefs = getHostPreference hostname;
        in
        import (getNixConfig "generate-nixos-configuration.nix") {
          inherit prefs inputs;
        };

      generateHomeConfigurations = name: inputs:
        let
          # The name may be of the format username@hostname or just hostname.
          matchResult = builtins.match "([^@]+)@([^@]+)" name;
          username = if (matchResult == null) then prefs.owner else (builtins.elemAt matchResult 0);
          hostname = if (matchResult == null) then name else (builtins.elemAt matchResult 1);
          # If we are using the default home directory (which likely means that we haven't overriden it),
          # then we are better of using /home/${username} in home-manager.
          home = if (prefs.home == prefs.defaultHome) then "/home/${username}" else prefs.home;
          configName = if (matchResult == null) then "${username}@${hostname}" else name;
          prefs = getHostPreference hostname;
          moduleArgs = {
            inherit inputs hostname prefs;
            inherit (prefs) isMinimalSystem isVirtualMachine system;
          };
        in
        {
          "${configName}" = inputs.home-manager.lib.homeManagerConfiguration {
            pkgs = self.pkgs."${prefs.system}";
            modules = [
              ({ ... }: {
                config = {
                  _module.args = moduleArgs;
                };
              })
              (getNixConfig "/home.nix")
              {
                home =
                  {
                    inherit username;
                    homeDirectory = home;
                    stateVersion = prefs.homeManagerStateVersion;
                  };
              }
            ];
          };
        };

      generateDeployNode = hostname:
        let p = getHostPreference hostname;
        in
        {
          "${hostname}" = {
            hostname = p.hostname;
            profiles = {
              system = {
                user = "root";
                path = inputs.deploy-rs.lib."${p.system}".activate.nixos
                  self.nixosConfigurations."${p.hostname}";
              };
            };
          };
        };
    in
    let
      deployNodes = [ "ssg" "jxt" "shl" "mdq" "aol" ];
      # "dbx" for vagrant, "dvm" for microvm, "dqe" for qemu
      # "adx" is another vagrant box based on arch linux
      vmNodes = [ "dbx" "dvm" "bigvm" "dqe" "adx" ];
      darwinNodes = [ "gcv" ];
      allHosts = deployNodes ++ vmNodes ++ [ "default" ] ++ (builtins.attrNames
        (import (getNixConfig "fixed-systems.nix")).systems);
      homeManagerHosts = [ "madbox" "contrun@zklab-5" ];
      homeManagerConfigs = darwinNodes ++ allHosts ++ homeManagerHosts;
    in
    (builtins.foldl' (a: e: lib.recursiveUpdate a e) { } [
      {
        # TODO: nix run --impure .#deploy-rs
        # failed with error: attribute 'currentSystem' missing
        apps = inputs.deploy-rs.apps;
      }
      {
        nixOnDroidConfigurations = {
          default = inputs.nix-on-droid.lib.nixOnDroidConfiguration {
            modules = [
              ({ pkgs, lib, config, ... }:
                let
                  sshdTmpDirectory = "${config.user.home}/.sshd-tmp";
                  sshdDirectory = "${config.user.home}/.sshd";
                  dotfilesDirectory = "${config.user.home}/.local/share/chezmoi";
                  dotfilesRepo = "https://github.com/contrun/dotfiles";
                  githubUser = "contrun";
                  port = 8822;
                in
                {
                  build.activation.sshd = ''
                    $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents "${config.user.home}/.ssh"
                    if [[ ! -f "${config.user.home}/.ssh/authorized_keys" ]]; then
                      # ssh-import-id requires ssh-keygen
                      if ! PATH="${lib.makeBinPath [ pkgs.openssh ]}:$PATH" $DRY_RUN_CMD ${pkgs.ssh-import-id}/bin/ssh-import-id -o "${config.user.home}/.ssh/authorized_keys" "gh:${githubUser}"; then
                        $VERBOSE_ECHO "Importing ssh key from ${githubUser} failed"
                      fi
                    fi

                    if [[ ! -d "${sshdDirectory}" ]]; then
                      $DRY_RUN_CMD rm $VERBOSE_ARG --recursive --force "${sshdTmpDirectory}"
                      $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents "${sshdTmpDirectory}"

                      $VERBOSE_ECHO "Generating host keys..."
                      $DRY_RUN_CMD ${pkgs.openssh}/bin/ssh-keygen -t rsa -b 4096 -f "${sshdTmpDirectory}/ssh_host_rsa_key" -N ""

                      $VERBOSE_ECHO "Writing sshd_config..."
                      $DRY_RUN_CMD ${pkgs.python3}/bin/python -c 'with open("${sshdTmpDirectory}/sshd_config", "w") as f: f.write("HostKey ${sshdDirectory}/ssh_host_rsa_key\nPort ${toString port}\n")'

                      $DRY_RUN_CMD mv $VERBOSE_ARG "${sshdTmpDirectory}" "${sshdDirectory}"
                    fi
                  '';

                  build.activation.dotfiles = ''
                    if [[ ! -d "${dotfilesDirectory}" ]]; then
                      $DRY_RUN_CMD mkdir $VERBOSE_ARG --parents "${dotfilesDirectory}"
                      if ! $DRY_RUN_CMD ${pkgs.git}/bin/git clone "${dotfilesRepo}" "${dotfilesDirectory}"; then
                        $VERBOSE_ECHO "Cloning repo ${dotfilesRepo} into ${dotfilesDirectory} failed"
                      fi
                      if ! PATH="${lib.makeBinPath [ pkgs.coreutils pkgs.diffutils pkgs.gnupg pkgs.gnugrep pkgs.gnused pkgs.curl pkgs.chezmoi pkgs.git ]}:$PATH" $DRY_RUN_CMD ${pkgs.gnumake}/bin/make -C "${dotfilesDirectory}" home-install; then
                        $VERBOSE_ECHO "Installing dotfiles failed"
                      fi
                    fi
                  '';

                  environment.packages = with pkgs; [
                    git
                    man
                    openssh
                    gnupg
                    mosh
                    coreutils
                    rsync
                    diffutils
                    gnugrep
                    gnused
                    gawk
                    curl
                    neovim
                    chezmoi
                    gnumake
                    (writeShellApplication {
                      name = "sshd-start";
                      text = ''
                        # May fail with `Cannot bind netlink socket: Permission denied`
                        if ! ip -brief addr show scope global up; then
                          :
                        fi
                        echo "Starting sshd on port ${toString port}"
                        # sshd re-exec requires execution with an absolute path
                        exec "$(command -v sshd)" -f "${sshdDirectory}/sshd_config" -D "$@"
                      '';
                      runtimeInputs = with pkgs; [ iproute2 openssh ];
                    })
                  ];
                  system.stateVersion = "22.05";
                })
            ];
            # set nixpkgs instance, it is recommended to apply `nix-on-droid.overlays.default`
            pkgs = import nixpkgs {
              system = "aarch64-linux";

              overlays = [
                nix-on-droid.overlays.default
                (final: prev: {
                  mosh = self.packages."aarch64-linux".mosh;
                  ssh = self.packages."aarch64-linux".ssh;
                })
              ];
            };

            # set path to home-manager flake
            home-manager-path = home-manager.outPath;
          };
        };
      }
      {
        nixosConfigurations = builtins.foldl'
          (acc: hostname: acc // generateHostConfigurations hostname inputs)
          { }
          allHosts;

        homeConfigurations = builtins.foldl'
          (acc: name: acc // generateHomeConfigurations name inputs)
          { }
          homeManagerConfigs;

        deploy.nodes =
          builtins.foldl' (acc: hostname: acc // (generateDeployNode hostname))
            { }
            deployNodes;

        overlayList = [
          # inputs.nixpkgs-wayland.overlay
          inputs.emacs-overlay.overlay
        ] ++ (lib.attrValues self.overlays);

        overlays = (import (getNixConfig "overlays.nix") { inherit inputs; }) // {
          nixpkgsChannelsOverlay = self: super: {
            unstable = import inputs.nixpkgs-unstable {
              inherit (super) system config;
            };
            stable = import inputs.nixpkgs-stable {
              inherit (super) system config;
            };
          };

          haskellOverlay = self: super:
            let
              originalCompiler = super.haskell.compiler;
              newCompiler = super.callPackages inputs.old-ghc-nix { pkgs = super; };
            in
            {
              haskell = super.haskell // {
                inherit originalCompiler newCompiler;
                compiler = newCompiler // originalCompiler;
              };
            };

          mozillaOverlay = import inputs.nixpkgs-mozilla;

          myPackagesOverlay = self: super: {
            myPackages =
              let
                list =
                  [{
                    name = "firefox";
                    pkg = inputs.flake-firefox-nightly.packages."${super.system}".firefox-nightly-bin or null;
                  }]
                  ++
                  (builtins.map
                    (name: {
                      inherit name;
                      pkg = inputs.${name}.defaultPackage.${super.system} or null;
                    })
                    [ "aioproxy" "deploy-rs" "home-manager" "nix-autobahn" "helix" ])
                  ++
                  (builtins.concatLists (builtins.attrValues
                    (builtins.mapAttrs
                      (repo: packages: builtins.map
                        (name: {
                          inherit name;
                          pkg = inputs.${repo}.packages.${super.system}.${name} or null;
                        })
                        packages)
                      {
                        "nix-alien" = [ "nix-alien" "nix-index-update" ];
                      }
                    )
                  ))
                  ++
                  (builtins.map
                    (name: {
                      inherit name;
                      pkg = inputs.self.packages.${super.system}.${name} or null;
                    })
                    [ "magit" "coredns" "ssh" "mosh" "ssho" "mosho" ]);
                function = acc: elem: acc //
                (if (elem.pkg != null) then {
                  ${elem.name} = elem.pkg;
                } else
                  { });
              in
              (builtins.foldl' function { } list) // (super.myPackages or { });
          };
        };


        checks = builtins.mapAttrs
          (system: deployLib: deployLib.deployChecks self.deploy)
          inputs.deploy-rs.lib;
      }
      (with flake-utils.lib;
      eachSystem defaultSystems
        (system:
          let
            config = {
              android_sdk.accept_license = true;
              allowUnfree = true;
            };
            pkgs = import nixpkgs {
              inherit system config;
            };

            pkgsRiscvLinux = import nixpkgs {
              inherit system config;
              crossSystem = (import nixpkgs { }).lib.systems.examples.riscv64;
              useLLVM = true;
            };

            pkgsRiscvEmbeded = import nixpkgs {
              inherit system config;
              crossSystem = (import nixpkgs { }).lib.systems.examples.riscv64-embedded;
              useLLVM = true;
            };

            pkgsToBuildLocalPackages = import nixpkgs {
              inherit system config;
              overlays = [
                (import "${gomod2nix}/overlay.nix")
              ];
            };

            pkgsWithOverlays = import nixpkgs {
              inherit system config;
              overlays = self.overlayList;
            };

            pkgsUnstable = import inputs.nixpkgs-unstable {
              inherit system config;
            };

            pkgsUnstableWithOverlays = import inputs.nixpkgs-unstable {
              inherit system config;
            };
          in
          rec {
            inherit pkgs pkgsWithOverlays pkgsUnstable pkgsUnstableWithOverlays;

            # Make packages from nixpkgs available, we can, for example, run
            # nix shell '.#python3Packages.invoke'
            legacyPackages = pkgs;

            devShell = with pkgsToBuildLocalPackages; mkShell { buildInputs = [ go ansible cachix deploy-rs sops nixpkgs-fmt pre-commit ]; };

            devShells = with pkgsToBuildLocalPackages;  {
              # Enroll gpg key with
              # nix-shell -p gnupg -p ssh-to-pgp --run "ssh-to-pgp -private-key -i /tmp/id_rsa | gpg --import --quiet"
              # Edit secrets.yaml file with
              # nix develop ".#sops" --command sops ./nix/sops/secrets.yaml
              sops = mkShell {
                sopsPGPKeyDirs = [ ./nix/sops/keys ];
                nativeBuildInputs = [
                  (callPackage inputs.sops-nix { }).sops-import-keys-hook
                ];
                shellHook = ''
                  alias s="sops"
                '';
              };

              riscvEmbeded = pkgsRiscvEmbeded.mkShell { };


              riscvEmbeddedClang = let mkShell = pkgsRiscvEmbeded.mkShell.override {
                stdenv = pkgsRiscvEmbeded.clangStdenv;
              }; in
                mkShell {
                  nativeBuildInputs = [ ];
                };

              riscvLinux = pkgsRiscvLinux.mkShell { };

              cuda = pkgs.mkShell {
                buildInputs = with pkgs; [
                  linuxPackages.nvidia_x11
                  cudaPackages.cudatoolkit
                  cudaPackages.cudnn
                  cudaPackages.libcublas
                  cudaPackages.cuda_cudart
                  libGLU
                  libGL
                  xorg.libXi
                  xorg.libXmu
                  freeglut
                  xorg.libXext
                  xorg.libX11
                  xorg.libXv
                  xorg.libXrandr
                  zlib
                  ncurses5
                  stdenv.cc
                  binutils
                  (pkgs.python3.withPackages (ps: with ps; [
                    pip
                    jupyterlab
                    jupyterhub
                    jupyterhub-systemdspawner
                    pandas
                    numpy
                    requests
                    transformers
                    huggingface-hub
                    pytorchWithCuda
                    jaxlibWithCuda
                    jax
                  ]))
                ];

                shellHook = ''
                  export LD_LIBRARY_PATH="${pkgs.linuxPackages.nvidia_x11}/lib"
                '';
              };

              # https://stackoverflow.com/questions/77174188/nixos-issues-with-flutter-run
              # Note that the emulator does not work here.
              android =
                let
                  latestVersion = "34";
                  # special version for aapt2 (usually latest available)
                  buildToolsVersionForAapt2 = "${latestVersion}.0.0";
                  # Installing android sdk
                  androidComposition = pkgs.androidenv.composeAndroidPackages {
                    # Installing both version for aapt2 and version that flutter wants
                    buildToolsVersions = [ buildToolsVersionForAapt2 "30.0.3" ];
                    includeSystemImages = true;
                    platformVersions = [ latestVersion "28" ];
                    abiVersions = [ "arm64-v8a" ] ++ (if system == "x86_64-linux" then [ "x86_64" ] else [ ]);
                    includeEmulator = true;
                    includeNDK = true;
                    includeSources = true;
                  };
                  androidSdk = androidComposition.androidsdk;
                  pinnedJDK = pkgs.jdk17;
                in
                pkgs.mkShell {
                  ANDROID_SDK_ROOT = "${androidSdk}/libexec/android-sdk";
                  # specify gradle the aapt2 executable
                  GRADLE_OPTS = "-Dorg.gradle.project.android.aapt2FromMavenOverride=${androidSdk}/libexec/android-sdk/build-tools/${buildToolsVersionForAapt2}/aapt2";
                  buildInputs = [
                    flutter
                    android-studio

                    androidSdk
                    pinnedJDK

                    xorg.libX11
                  ];
                };

              ckb =
                with pkgs;
                mkShell {
                  nativeBuildInputs =
                    [
                      llvmPackages.clang
                      pkg-config
                      rustup
                    ];
                  buildInputs = [
                    llvmPackages.libclang
                    llvmPackages.libclang.dev
                    llvmPackages.libclang.lib
                    rocksdb
                    openssl
                  ];
                  # run time dependencies
                  LIBCLANG_PATH = "${llvmPackages.libclang.lib}/lib";
                  RUST_BACKTRACE = "full";
                };

              dotnetNativeAOT =
                pkgs.mkShell rec {

                  dotnetPkg =
                    (with dotnetCorePackages; combinePackages [
                      sdk_7_0
                      sdk_8_0
                    ]);

                  deps = [
                    zlib
                    zlib.dev
                    openssl
                    icu
                    dotnetPkg
                  ];

                  NIX_LD_LIBRARY_PATH = lib.makeLibraryPath ([
                    stdenv.cc.cc
                  ] ++ deps);
                  NIX_LD = "${pkgs.stdenv.cc.libc_bin}/bin/ld.so";
                  nativeBuildInputs = [
                    omnisharp-roslyn
                    fsautocomplete
                  ] ++ deps;

                  shellHook = ''
                    DOTNET_ROOT="${dotnetPkg}";
                  '';
                };

              dotnet =
                pkgs.mkShell rec {

                  dotnetPkg =
                    (with dotnetCorePackages; combinePackages [
                      sdk_6_0
                      sdk_7_0
                      sdk_8_0
                    ]);

                  deps = [
                    zlib
                    zlib.dev
                    openssl
                    icu
                    dotnetPkg
                  ];

                  NIX_LD_LIBRARY_PATH = lib.makeLibraryPath ([
                    stdenv.cc.cc
                  ] ++ deps);
                  NIX_LD = "${pkgs.stdenv.cc.libc_bin}/bin/ld.so";
                  nativeBuildInputs = [
                    omnisharp-roslyn
                    fsautocomplete
                  ] ++ deps;

                };

            };

            apps =
              {
                run = {
                  type = "app";
                  program = "${self.packages."${system}".run}/bin/run";
                };

                magit = {
                  type = "app";
                  program = "${self.packages."${system}".magit}/bin/magit";
                };
              };

            defaultApp = apps.run;

            packages =
              let
                start-agent-script = ''
                  GPG_SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket || true)"

                  try_use_gpg_ssh_agent() {
                    MESSAGE="$(LC_ALL=en_US.UTF-8 SSH_AUTH_SOCK="$GPG_SSH_AUTH_SOCK" ssh-add -L 2>&1)"
                    if [[ "$MESSAGE" == 'Could not open a connection to your authentication agent.' ]] || \
                      [[ "$MESSAGE" == 'Error connecting to agent: Connection refused' ]] || \
                      [[ "$MESSAGE" == 'Error connecting to agent: No such file or directory' ]] || \
                      [[ "$MESSAGE" == 'The agent has no identities.' ]]; then
                      return 1
                    fi
                    GPG_TTY="$(tty)"
                    export GPG_TTY="$GPG_TTY" SSH_AUTH_SOCK="$GPG_SSH_AUTH_SOCK"
                  }

                  try_start_ssh_agent() {
                    : "''${SSH_AUTH_SOCK:=''${HOME}/.ssh/ssh_auth_sock}"
                    # We will not be able to add identities to gpg ssh agent.
                    if [[ "$SSH_AUTH_SOCK" == "$GPG_SSH_AUTH_SOCK" ]]; then
                       SSH_AUTH_SOCK="''${HOME}/.ssh/ssh_auth_sock"
                    fi
                    export SSH_AUTH_SOCK

                    MESSAGE=$(LC_ALL=en_US.UTF-8 ssh-add -L 2>&1)
                    if [[ "$MESSAGE" == 'Could not open a connection to your authentication agent.' ]] || \
                      [[ "$MESSAGE" == 'Error connecting to agent: Connection refused' ]] || \
                      [[ "$MESSAGE" == 'Error connecting to agent: No such file or directory' ]]; then
                      rm -f "$SSH_AUTH_SOCK"
                      ssh-agent -a "$SSH_AUTH_SOCK" > /dev/null
                      ssh-add
                    elif [[ "$MESSAGE" == 'The agent has no identities.' ]]; then
                      ssh-add
                    fi
                  }

                  try_use_gpg_ssh_agent || try_start_ssh_agent || true
                '';
              in
              {
                nixos-generators = {
                  vbox = inputs.nixos-generators.nixosGenerate {
                    system = "x86_64-linux";
                    format = "virtualbox";
                  };
                  qcow = inputs.nixos-generators.nixosGenerate {
                    system = "x86_64-linux";
                    format = "vagrant-virtualbox";
                  };
                  vagrant = inputs.nixos-generators.nixosGenerate {
                    system = "x86_64-linux";
                    format = "vagrant-virtualbox";
                  };
                };

                containers = let genContainers = import ./nix/containers.nix; in genContainers { inherit pkgs; };

                run = with pkgs; writeShellApplication {
                  name = "run";
                  text = ''
                    make -C "${lib.cleanSource ./.}" "$@"
                  '';
                  runtimeInputs = [ gnumake nixUnstable jq coreutils findutils home-manager ];
                };

                ssh = with pkgs; writeShellApplication {
                  name = "ssh";
                  text = ''
                    ${start-agent-script}
                    if [[ "$TERM" == foot ]]; then
                      export TERM=xterm-256color
                    fi
                    ssh "$@"
                  '';
                  runtimeInputs = [ coreutils gnupg openssh ];
                };

                mosh = with pkgs; writeShellApplication {
                  name = "mosh";
                  text = ''
                    ${start-agent-script}
                    # See https://github.com/termux/termux-packages/issues/288
                    LC_ALL="''${LC_ALL:-en_US.UTF-8}" mosh "$@"
                  '';
                  runtimeInputs = [ coreutils gnupg openssh mosh ];
                };

                ssho = with pkgs; writeShellApplication {
                  name = "ssho";
                  text = ''
                    if [[ "$TERM" == foot ]]; then
                      export TERM=xterm-256color
                    fi
                    ssh "$@"
                  '';
                  runtimeInputs = [ coreutils gnupg openssh ];
                };

                mosho = with pkgs; writeShellApplication {
                  name = "mosho";
                  text = ''
                    # See https://github.com/termux/termux-packages/issues/288
                    LC_ALL="''${LC_ALL:-en_US.UTF-8}" mosh "$@"
                  '';
                  runtimeInputs = [ coreutils gnupg openssh mosh ];
                };

                dvm =
                  let
                    inherit (self.nixosConfigurations.dvm) config;
                    # quickly build with another hypervisor if this MicroVM is built as a package
                    hypervisor = "qemu";
                  in
                  config.microvm.runner.${hypervisor};

                magit = with pkgs; writeShellApplication {
                  name = "magit";
                  text = ''
                    function usage() {
                        cat <<EOF
                    magit [EMACS_OPTIONS] [PATH]
                    If the last arguments is a valid directory, then run magit within it,
                    else all arguments are passed to emacs.
                    Run emacs --help to see emacs options.
                    EOF
                    }

                    for i in "$@" ; do
                        if [[ "$i" == "--help" ]] || [[ "$i" == "-h" ]]; then
                            usage
                            exit
                        fi
                    done

                    emacs_arguments=( "''${@}" )

                    if [[ $# -gt 0 ]]; then
                        path="''${*: -1}"
                        if [[ -d "$path" ]]; then
                            cd "$path"
                            emacs_arguments=( "''${@:1: (( $# -1 )) }" )
                        fi
                    fi

                    emacs -q -l magit -f magit --eval "(local-set-key \"q\" #'kill-emacs)" -f delete-other-windows "''${emacs_arguments[@]}"
                  '';
                  runtimeInputs = [
                    git
                    (emacsWithPackages (epkgs: [ epkgs.magit ]))
                  ];
                };

                riscv-gnu-toolchain-shell = with pkgs;
                  with stdenv;
                  with stdenv.lib;
                  pkgs.mkShell {
                    name = "riscv-shell";
                    nativeBuildInputs = with pkgs.buildPackages; [ bash gnumake cmake curl git utillinux ];
                    buildInputs = with pkgs; [
                      stdenv
                      binutils
                      cmake
                      pkg-config
                      curl
                      autoconf
                      automake
                      python3
                      libmpc
                      mpfr
                      gmp
                      gawk
                      bison
                      flex
                      texinfo
                      gperf
                      libtool
                      patchutils
                      bc
                      libdeflate
                      expat
                      gnumake
                      pkgs.gnumake

                      utillinux
                      bash
                    ];

                    hardeningDisable = [ "all" ];
                  };

                riscv-gnu-toolchain = with pkgs; stdenv.mkDerivation rec {
                  pname = "riscv-gnu-toolchain";
                  version = "2024.03.01";

                  src = fetchFromGitHub {
                    owner = "riscv-collab";
                    repo = "riscv-gnu-toolchain";
                    rev = "${version}";
                    sha256 = "sha256-X3EkqHyp2NykFbP3fLMrTLFYd+/JgfxomtsHp742ipI=";
                    leaveDotGit = true;
                  };

                  postPatch = ''
                    # hack for unknown issue in fetchgit
                    git reset --hard
                    patchShebangs ./scripts
                  '';

                  nativeBuildInputs = [
                    python3
                    util-linux
                    git
                    cacert
                    autoconf
                    automake
                    curl
                    python3
                    gawk
                    bison
                    flex
                    texinfo
                    gperf
                    bc
                  ];

                  buildInputs = [
                    libmpc
                    mpfr
                    gmp
                    zlib
                    expat
                  ];

                  configureFlags = [
                    "--enable-llvm"
                  ];

                  makeFlags = [
                    "newlib"
                    "linux"
                  ];

                  hardeningDisable = [
                    "format"
                  ];

                  enableParallelBuilding = true;

                  __noChroot = true;
                };

                coredns = pkgsToBuildLocalPackages.buildGoApplication {
                  pname = "coredns";
                  version = "latest";
                  goPackagePath = "github.com/contrun/infra/coredns";
                  src = ./coredns;
                  modules = ./coredns/gomod2nix.toml;
                };

                # Todo: gomod2nix failed
                caddy = pkgsToBuildLocalPackages.buildGoApplication {
                  pname = "caddy";
                  version = "latest";
                  goPackagePath = "github.com/contrun/infra/caddy";
                  src = ./caddy;
                  modules = ./caddy/gomod2nix.toml;
                  nativeBuildInputs = [ pkgs.musl ];

                  CGO_ENABLED = 0;

                  ldflags = [
                    "-linkmode external"
                    "-extldflags '-static -L${pkgs.musl}/lib'"
                  ];
                };
              };
          }))
    ]) //
    {
      # Templates for use with zig flake init
      templates.dotnet-ml = {
        path = ./nix/templates/dotnet-ml;
        description = "A development environment for machine learning on dotnet.";
      };
    }
  ;
}
