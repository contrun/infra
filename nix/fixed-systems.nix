rec {
  systemsList = [
    "x86_64-linux"
    "aarch64-linux"

    # deploy-rs will fail if the following are added. Comment out for now.
    # "i686-linux"
    # "x86_64-darwin"
    # "armv6l-linux"
    # "armv7l-linux"
  ];
  systems =
    builtins.foldl' (acc: current: acc // { "${current}" = current; }) { }
    systemsList
    // builtins.foldl' (acc: current: acc // { "cicd-${current}" = current; })
    { } systemsList;
}
