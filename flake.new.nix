{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    deploy-rs.url = "github:serokell/deploy-rs";
    deploy-rs.inputs.nixpkgs.follows = "nixpkgs";
    deploy-rs.inputs.utils.follows = "flake-utils";
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
      };
    };
    nixos-vscode-server = {
      url = "github:msteen/nixos-vscode-server";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, flake-utils, gomod2nix, ... }@inputs:
    let
      getNixConfig = path: ./. + "/nix/${path}";

      getHostPreference = hostname:
        let
          old = ((import (getNixConfig "prefs.nix")) {
            inherit hostname inputs;
          }).pure;
        in
        old // { system = old.nixosSystem; };

      generateHostConfigurations = hostname: inputs:
        let
          p = getHostPreference hostname;
          pjson = builtins.toJSON (inputs.nixpkgs.lib.filterAttrsRecursive
            (n: v: !builtins.elem (builtins.typeOf v) [ "lambda" ])
            p);
          prefs =
            builtins.trace "mininal json configuration for host ${hostname}"
              (builtins.trace pjson p);
        in
        import (getNixConfig "generate-nixos-configuration.nix") {
          inherit prefs inputs;
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

      out = system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ gomod2nix.overlay ];
          };
        in
        {

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
    in
    let
      deployNodes = [ "ssg" "jxt" "shl" "mdq" ];
      vmNodes = [ "bigvm" ];
      allHosts = deployNodes ++ vmNodes ++ [ "default" ] ++ (builtins.attrNames
        (import (getNixConfig "fixed-systems.nix")).systems);
    in
    {

      nixosConfigurations = builtins.foldl'
        (acc: hostname: acc // generateHostConfigurations hostname inputs)
        { }
        allHosts;

      deploy.nodes = builtins.foldl'
        (acc: hostname:
          acc // builtins.trace (generateDeployNode hostname)
            (generateDeployNode hostname))
        { }
        deployNodes;

      checks = builtins.mapAttrs
        (system: deployLib: deployLib.deployChecks self.deploy)
        inputs.deploy-rs.lib;

    } // (with flake-utils.lib; eachSystem defaultSystems out);
}
