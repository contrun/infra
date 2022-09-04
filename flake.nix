{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
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

    nix-ld.url = "github:Mic92/nix-ld";
    nix-ld.inputs.nixpkgs.follows = "nixpkgs";
    nix-ld.inputs.utils.follows = "flake-utils";

    nix-autobahn.url = "github:Lassulus/nix-autobahn";
    nix-autobahn.inputs.nixpkgs.follows = "nixpkgs";
    nix-autobahn.inputs.flake-utils.follows = "flake-utils";

    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.inputs.utils.follows = "flake-utils";
    deploy-rs.inputs.flake-compat.follows = "flake-compat";

    helix.url = "github:helix-editor/helix";
    helix.inputs.rust-overlay.follows = "rust-overlay";
    helix.inputs.flakeCompat.follows = "flake-compat";

    crate2nix.url = "github:kolloch/crate2nix";
    crate2nix.flake = false;

    rust-overlay.url = "github:oxalica/rust-overlay";
    rust-overlay.inputs.nixpkgs.follows = "nixpkgs";
    rust-overlay.inputs.flake-utils.follows = "flake-utils";

    gomod2nix.url = "github:tweag/gomod2nix";
    gomod2nix.inputs.nixpkgs.follows = "nixpkgs";
    gomod2nix.inputs.utils.follows = "flake-utils";

    nixpkgs-nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-20.09";

    aioproxy.url = "github:contrun/aioproxy";
    aioproxy.inputs.nixpkgs.follows = "nixpkgs";
    aioproxy.inputs.gomod2nix.follows = "gomod2nix";
    aioproxy.inputs.flake-utils.follows = "flake-utils";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    nix-on-droid.url = "github:t184256/nix-on-droid";
    nix-on-droid.inputs.nixpkgs.follows = "nixpkgs";
    nix-on-droid.inputs.home-manager.follows = "home-manager";
    nix-on-droid.inputs.flake-utils.follows = "flake-utils";

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
      flake = false;
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

  outputs = { self, nixpkgs, home-manager, flake-utils, gomod2nix, rust-overlay, crate2nix, ... }@inputs:
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

      generateHomeConfigurations = hostname: inputs:
        let
          prefs = getHostPreference hostname;
          moduleArgs = {
            inherit inputs hostname prefs;
            inherit (prefs) isMinimalSystem isVirtualMachine system;
          };
        in
        {
          "${prefs.owner}@${hostname}" = inputs.home-manager.lib.homeManagerConfiguration {
            inherit (prefs) system;
            homeDirectory = prefs.home;
            username = prefs.owner;
            stateVersion = prefs.homeManagerStateVersion;
            pkgs = self.nixpkgs."${prefs.system}";

            configuration = {
              _module.args = moduleArgs;

              imports = [
                (getNixConfig "/home.nix")
              ] ++ (if prefs.enableSmos then
                [ (inputs.smos + "/nix/home-manager-module.nix") ] else [ ])
              ;
            };
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
      vmNodes = [ "dbx" "dvm" "bigvm" ];
      darwinNodes = [ "gcv" ];
      allHosts = deployNodes ++ vmNodes ++ [ "default" ] ++ (builtins.attrNames
        (import (getNixConfig "fixed-systems.nix")).systems);
      homeManagerHosts = darwinNodes ++ allHosts;
    in
    (builtins.foldl' (a: e: lib.recursiveUpdate a e) { } [
      {
        # TODO: nix run --impure .#deploy-rs
        # failed with error: attribute 'currentSystem' missing
        apps = inputs.deploy-rs.apps;
      }
      {
        nixOnDroidConfigurations = {
          npo = inputs.nix-on-droid.lib.nixOnDroidConfiguration {
            config = { pkgs, config, ... }: {
              environment.packages = with pkgs; [ neovim chezmoi gnumake ];
              system.stateVersion = "22.05";
            };
            system = "aarch64-linux";
            extraModules = [
              # import source out-of-tree modules like:
              # flake.nixOnDroidModules.module
            ];
            extraSpecialArgs = {
              # arguments to be available in every nix-on-droid module
            };
            # your own pkgs instance (see nix-on-droid.overlay for useful additions)
            # pkgs = ...;
          };
        };
      }
      {
        nixosConfigurations = builtins.foldl'
          (acc: hostname: acc // generateHostConfigurations hostname inputs)
          { }
          allHosts;

        homeConfigurations = builtins.foldl'
          (acc: hostname: acc // generateHomeConfigurations hostname inputs)
          { }
          homeManagerHosts;

        deploy.nodes =
          builtins.foldl' (acc: hostname: acc // (generateDeployNode hostname))
            { }
            deployNodes;

        overlayList = [
          inputs.nixpkgs-wayland.overlay
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
                  (builtins.map
                    (name: {
                      inherit name;
                      pkg = inputs.self.packages.${super.system}.${name} or null;
                    })
                    [ "magit" "coredns" "ssha" "mosha" ]);
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
            pkgs = import nixpkgs {
              inherit system;
              overlays = [
                (import "${gomod2nix}/overlay.nix")
                rust-overlay.overlays.default
                (self: super: {
                  # Because rust-overlay bundles multiple rust packages into one
                  # derivation, specify that mega-bundle here, so that crate2nix
                  # will use them automatically.
                  rustc = self.rust-bin.stable.latest.default;
                  cargo = self.rust-bin.stable.latest.default;
                })
              ];
            };

            inherit (import "${crate2nix}/tools.nix" { inherit pkgs; })
              generatedCargoNix;

            nixpkgsWithOverlays = import nixpkgs {
              inherit system;
              overlays = self.overlayList;
            };
          in
          rec {
            nixpkgs = nixpkgsWithOverlays;

            # Make packages from nixpkgs available, we can, for example, run
            # nix shell '.#python3Packages.invoke'
            legacyPackages = nixpkgsWithOverlays;

            devShell = pkgs.mkShell { buildInputs = with pkgs; [ go ]; };

            devShells = {
              # Enroll gpg key with
              # nix-shell -p gnupg -p ssh-to-pgp --run "ssh-to-pgp -private-key -i /tmp/id_rsa | gpg --import --quiet"
              # Edit secrets.yaml file with
              # nix develop ".#sops" --command sops ./nix/sops/secrets.yaml
              sops = pkgs.mkShell {
                sopsPGPKeyDirs = [ ./nix/sops/keys ];
                nativeBuildInputs = [
                  (pkgs.callPackage inputs.sops-nix { }).sops-import-keys-hook
                ];
                shellHook = ''
                  alias s="sops"
                '';
              };
            };
            apps = {
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
                  set +o errexit
                  start_agent() {
                    ssh-agent -a "$1" > /dev/null
                    ssh-add
                  }

                  export SSH_AUTH_SOCK="''${SSH_AUTH_SOCK:-''${HOME}/.ssh/ssh_auth_sock}"

                  MESSAGE=$(LC_ALL=en_US.UTF-8 ssh-add -L 2>&1)
                  if [[ "$MESSAGE" = 'Could not open a connection to your authentication agent.' ]] || \
                    [[ "$MESSAGE" = 'Error connecting to agent: Connection refused' ]] || \
                    [[ "$MESSAGE" = 'Error connecting to agent: No such file or directory' ]]; then
                    rm -f "$SSH_AUTH_SOCK"
                    start_agent "$SSH_AUTH_SOCK"
                  elif [ "$MESSAGE" = "The agent has no identities." ]; then
                    ssh-add
                  fi
                  set -o errexit
                '';
              in
              {
                nixos-generators = {
                  vbox = inputs.nixos-generators.nixosGenerate {
                    system = "x86_64-linux";
                    format = "virtualbox";
                  };
                  vagrant = inputs.nixos-generators.nixosGenerate {
                    system = "x86_64-linux";
                    format = "vagrant-virtualbox";
                  };
                };

                containers = {
                  texlive = with nixpkgsWithOverlays; dockerTools.buildImage
                    rec {
                      name = "texlive-full";
                      tag = "latest";
                      created = "now";
                      contents = buildEnv {
                        inherit name;
                        paths = [
                          (texlive.combine { inherit (texlive) scheme-full; })
                          adoptopenjdk-bin
                          font-awesome_4
                          font-awesome_5
                          nerdfonts
                          pdftk
                          bash
                          gnugrep
                          gnused
                          coreutils
                          gnumake
                        ];
                      };
                      config.Cmd = [ "/bin/bash" ];
                    };
                };

                run = with nixpkgsWithOverlays; writeShellApplication {
                  name = "run";
                  text = ''
                    make -C "${lib.cleanSource ./.}" "$@"
                  '';
                  runtimeInputs = [ gnumake nixUnstable jq coreutils findutils home-manager ];
                };

                ssha = with nixpkgsWithOverlays; writeShellApplication {
                  name = "ssha";
                  text = ''
                    ${start-agent-script}
                    ssh "$@"
                  '';
                  runtimeInputs = [ coreutils openssh ];
                };

                mosha = with nixpkgsWithOverlays; writeShellApplication {
                  name = "mosha";
                  text = ''
                    ${start-agent-script}
                    mosh "$@"
                  '';
                  runtimeInputs = [ coreutils openssh mosh ];
                };

                dvm =
                  let
                    inherit (self.nixosConfigurations.dvm) config;
                    # quickly build with another hypervisor if this MicroVM is built as a package
                    hypervisor = "qemu";
                  in
                  config.microvm.runner.${hypervisor};

                magit = with nixpkgsWithOverlays; writeShellApplication {
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


                coredns = pkgs.buildGoApplication {
                  pname = "coredns";
                  version = "latest";
                  goPackagePath = "github.com/contrun/infra/coredns";
                  src = ./coredns;
                  modules = ./coredns/gomod2nix.toml;
                };

                # Todo: gomod2nix failed
                caddy = pkgs.buildGoApplication {
                  pname = "caddy";
                  version = "latest";
                  goPackagePath = "github.com/contrun/infra/caddy";
                  src = ./caddy;
                  modules = ./caddy/gomod2nix.toml;
                };
              };
          }))
    ]);
}
