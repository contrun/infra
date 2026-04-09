{
  pkgs,
  lib,
  ...
}:
pkgs.dockerTools.buildLayeredImage {
  name = "wstunnel";
  tag = "latest";

  config = {
    Entrypoint = [
      "${lib.getExe pkgs.tini}"
      "--"
      "${lib.getExe pkgs.wstunnel}"
    ];
  };
}
