with import <nixpkgs> { };
# Enroll gpg key with
# nix-shell -p gnupg -p ssh-to-pgp --run "ssh-to-pgp -private-key -i /tmp/id_rsa | gpg --import --quiet"
# Edit secrets.yaml file with
# nix-shell -p sops --run "sops secrets.yaml"
mkShell {
  sopsPGPKeyDirs = [ ./keys ];
  nativeBuildInputs = [
    (pkgs.callPackage "${builtins.fetchTarball
      "https://github.com/Mic92/sops-nix/archive/master.tar.gz"}"
      { }).sops-pgp-hook
  ];
}
