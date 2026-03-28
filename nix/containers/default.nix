{
  pkgs,
  packages,
  zotero-plugins,
}:
let
  inherit (pkgs) lib;
  # Common arguments passed to most sub-modules
  args = { inherit pkgs lib; };
in
{
  rclone = import ./rclone.nix args;

  aria2 = import ./aria2.nix args;

  owntracks = import ./owntracks.nix args;

  tailscale = import ./tailscale.nix args;

  caddy = import ./caddy.nix (args // { inherit packages; });

  zotero = import ./zotero.nix (args // { inherit packages zotero-plugins; });
}
