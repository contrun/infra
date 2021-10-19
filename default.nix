{ system ? builtins.currentSystem }:
let rootDirectory = ./.;
in (import (let
  lock = builtins.fromJSON (builtins.readFile "${rootDirectory}/flake.lock");
  locked = lock.nodes.flake-compat-result.locked;
in fetchTarball {
  url =
    "https://github.com/${locked.owner}/${locked.repo}/archive/${locked.rev}.tar.gz";
  sha256 = locked.narHash;
}) {
  src = rootDirectory;
  inherit system;
}).defaultNix.legacyPackages.${system}
