{ pkgs
, config
, ...
}: {
  environment.packages = with pkgs; [ neovim chezmoi gnumake ];
  system.stateVersion = "22.05";
}
