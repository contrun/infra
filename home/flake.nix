{
  description = "Nixos configurations";

  inputs = { };

  outputs = { ... } @ inputs: { getDotfile = path: ./. + "/${path}"; };
}
