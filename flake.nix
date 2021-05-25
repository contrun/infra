{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    gomod2nix.url = "github:tweag/gomod2nix";
    gomod2nix.inputs.nixpkgs.follows = "nixpkgs";
    gomod2nix.inputs.utils.follows = "flake-utils";
    nixpkgs-nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixpkgs-stable.url = "github:NixOS/nixpkgs/nixos-20.09";
    aioproxy.url = "github:contrun/aioproxy/master";
    aioproxy.inputs.nixpkgs.follows = "nixpkgs";
    aioproxy.inputs.gomod2nix.follows = "gomod2nix";
    aioproxy.inputs.flake-utils.follows = "flake-utils";
    home-manager.url = "github:nix-community/home-manager/master";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
    nur-no-pkgs.url = "github:nix-community/NUR/master";
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
    old-ghc-nix = {
      url = "github:mpickering/old-ghc-nix";
      flake = false;
    };
    dotfiles.url = "github:contrun/dotfiles";
  };

  outputs = { self, nixpkgs, flake-utils, gomod2nix, ... }@inputs:
    let
      getNixConfig = path: ./. + "/nix/${path}";

      getHostPreference = hostname:
        let
          old = ((import (getNixConfig "prefs.nix")) {
            inherit hostname inputs;
          }).pure;
        in old // { system = old.nixosSystem; };

      generateHostConfigurations = hostname: inputs:
        let
          p = getHostPreference hostname;
          pjson = builtins.toJSON (inputs.nixpkgs.lib.filterAttrsRecursive
            (n: v: !builtins.elem (builtins.typeOf v) [ "lambda" ]) p);
          prefs =
            builtins.trace "mininal json configuration for host ${hostname}"
            (builtins.trace pjson p);
        in import (getNixConfig "generate-nixos-configuration.nix") {
          inherit prefs inputs;
        };

      out = system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ gomod2nix.overlay ];
          };
        in {

          devShell = pkgs.mkShell { buildInputs = with pkgs; [ go ]; };

          coredns = pkgs.buildGoApplication {
            pname = "coredns";
            version = "latest";
            goPackagePath = "github.com/contrun/infra/coredns";
            src = ./coredns;
            modules = ./coredns/gomod2nix.toml;
          };

          # TODO: gomod2nix failed with
          #
          # caddy = pkgs.buildGoApplication {
          #   pname = "caddy";
          #   version = "latest";
          #   goPackagePath = "github.com/contrun/infra/caddy";
          #   src = ./caddy;
          #   modules = ./caddy/gomod2nix.toml;
          # };

        };
    in {
      nixosConfigurations = builtins.foldl'
        (acc: hostname: acc // generateHostConfigurations hostname inputs) { }
        ([ "default" ] ++ [ "ssg" "jxt" "shl" ] ++ (builtins.attrNames
          (import (getNixConfig "fixed-systems.nix")).systems));
    } // (with flake-utils.lib; eachSystem defaultSystems out);
}
