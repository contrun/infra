{ lib, ... }@args: rec {
  atoi = string:
    with builtins;
    let
      s = lib.toLower string;
      f = v: k: { "${k}" = v; };
      dec_alphabet = [ "0" "1" "2" "3" "4" "5" "6" "7" "8" "9" ];
      dec_set = foldl' (x: y: x // y) { } (lib.imap0 f dec_alphabet);
      hex_alphabet = dec_alphabet ++ [ "a" "b" "c" "d" "e" "f" ];
      hex_set = foldl' (x: y: x // y) { } (lib.imap0 f hex_alphabet);
      try_dec = ((stringLength s) < 2 || !elem (substring 0 2 s) [ "0x" "0X" ]);
      set = if try_dec then dec_set else hex_set;
      base = (length (lib.attrValues set));
      str = if try_dec then s else substring 2 ((stringLength s) - 2) s;
      list = map (x: set."${x}") (lib.stringToCharacters str);
      go = base: list: foldl' (a: v: (a * base + v)) 0 list;
    in go base list;

  autossh = { hostname, serverName, ... }:
    let
      basePort = 32768;
      bias = 4096;
      getPort = host: server: n:
        let
          hash = builtins.hashString "sha512"
            "${server}->${host}->${builtins.toString n}";
          port = atoi ("0x" + (builtins.substring 0 3 hash));
        in basePort + n * bias + port;
      go = n: getPort hostname serverName n;
    in map go [ 1 2 ];

  getAttrOrNull = attrset: path:
    builtins.foldl' (acc: x: if acc ? ${x} then acc.${x} else null) attrset
    (lib.splitString "." path);

  mkIfAttrExists = attrset: path:
    let r = getAttrOrNull attrset path;
    in lib.mkIf (r != null) r;
}
