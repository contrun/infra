{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    gomod2nix.url = "github:tweag/gomod2nix";
    gomod2nix.inputs.nixpkgs.follows = "nixpkgs";
    gomod2nix.inputs.utils.follows = "flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils, gomod2nix }:
    let
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
    in with flake-utils.lib; eachSystem defaultSystems out;

}
