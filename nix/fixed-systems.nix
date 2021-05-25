rec {
  systemsList = [
    "x86_64-linux"
    "i686-linux"
    "x86_64-darwin"
    "aarch64-linux"
    "armv6l-linux"
    "armv7l-linux"
  ];
  systems =
    builtins.foldl' (acc: current: acc // { "${current}" = current; }) { }
    systemsList
    // builtins.foldl' (acc: current: acc // { "cicd-${current}" = current; })
    { } systemsList;
}
