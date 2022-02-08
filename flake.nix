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
    helix.inputs.nixpkgs.follows = "nixpkgs";
    helix.inputs.rust-overlay.follows = "rust-overlay";
    helix.inputs.flakeCompat.follows = "flake-compat";

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
        nixpkgs.follows = "nixpkgs";
        home-manager.follows = "home-manager";
        flake-compat.follows = "flake-compat";
      };
    };

    nixos-vscode-server = {
      url = "github:msteen/nixos-vscode-server";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, home-manager, flake-utils, gomod2nix, ... }@inputs:
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
      deployNodes = [ "ssg" "jxt" "shl" "mdq" ];
      vmNodes = [ "dbx" "bigvm" ];
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
        apps = inputs.home-manager.apps;
      }
      {
        # Make packages from nixpkgs available, we can, for example, run
        # nix shell '.#python3Packages.invoke'
        legacyPackages = inputs.nixpkgs.legacyPackages;
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
            myPackages = (super.myPackages or { }) // super.lib.optionalAttrs
              (inputs.flake-firefox-nightly.packages ? "${super.system}")
              {
                firefox =
                  inputs.flake-firefox-nightly.packages."${super.system}".firefox-nightly-bin;
              } // super.lib.optionalAttrs
              (inputs.aioproxy.defaultPackage ? "${super.system}")
              {
                aioproxy = inputs.aioproxy.defaultPackage.${super.system};
                deploy-rs = inputs.deploy-rs.defaultPackage.${super.system};
                home-manager = inputs.home-manager.defaultPackage.${super.system};
                nix-autobahn = inputs.nix-autobahn.defaultPackage.${super.system};
                helix = inputs.helix.defaultPackage.${super.system};
                magit = inputs.self.packages.${super.system}.magit;
                coredns = inputs.self.packages.${super.system}.coredns;
              };
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
              overlays = [ gomod2nix.overlay ];
            };
            nixpkgsWithOverlays = import nixpkgs {
              inherit system;
              overlays = self.overlayList;
            };
          in
          rec {
            nixpkgs = nixpkgsWithOverlays;

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

            packages = {
              run = with nixpkgsWithOverlays; writeShellApplication {
                name = "run";
                text = ''
                  make -C "${lib.cleanSource ./.}" "$@"
                '';
                runtimeInputs = [ gnumake nixUnstable jq coreutils findutils home-manager ];
              };

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

              # TODO: gomod2nix failed
              # caddy = pkgs.buildGoApplication {
              #   pname = "caddy";
              #   version = "latest";
              #   goPackagePath = "github.com/contrun/infra/caddy";
              #   src = ./caddy;
              #   modules = ./caddy/gomod2nix.toml;
              # };
            };
          }))
    ]);
}
