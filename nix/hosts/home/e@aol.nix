{
  pkgs,
  ...
}:
{
  prefs.emacs.enable = true;
  home.packages = with pkgs; [ mediamtx ];
  programs.obs-studio = {
    enable = true;
    plugins = with pkgs.obs-studio-plugins; [
      wlrobs
      obs-pipewire-audio-capture
    ];
  };
}
