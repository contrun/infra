{
  pkgs,
  packages,
  zotero-plugins,
}:
let
  inherit (pkgs) lib;

  allArgs = {
    inherit
      pkgs
      lib
      packages
      zotero-plugins
      ;
  };

  dirContents = builtins.readDir ./.;

  validFiles = lib.filterAttrs (
    name: type: type == "regular" && lib.hasSuffix ".nix" name && name != "default.nix"
  ) dirContents;

in
lib.mapAttrs' (
  name: value: lib.nameValuePair (lib.removeSuffix ".nix" name) (import (./. + "/${name}") allArgs)
) validFiles
