{
  description = "dotnet machine learning development.";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";

    # Used for shell.nix
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };

  outputs =
    { self
    , nixpkgs
    , flake-utils
    , ...
    } @ inputs:
    flake-utils.lib.eachDefaultSystem (
      system:
      let
        config = {
          allowUnfree = true;
        };
        pkgs = import nixpkgs { inherit system config; };
      in
      {
        devShells.default = with pkgs; mkShell rec {
          buildInputs = [
            cudaPackages.cudatoolkit
            cudaPackages.cudnn
            cudaPackages.libcublas
            cudaPackages.cuda_cudart
            libGLU
            libGL
            xorg.libXi
            xorg.libXmu
            freeglut
            xorg.libXext
            xorg.libX11
            xorg.libXv
            xorg.libXrandr
            zlib
            ncurses5
            stdenv.cc
            binutils
            zlib
            zlib.dev
            openssl
            icu
            (pkgs.python3.withPackages (ps: with ps; [
              pip
              jupyterlab
              jupyterhub
              jupyterhub-systemdspawner
              pandas
              numpy
              requests
              transformers
              huggingface-hub
              pytorchWithCuda
              jaxlibWithCuda
              jax
            ]))
          ];

          shellHook = ''
            export LD_LIBRARY_PATH="${pkgs.linuxPackages.nvidia_x11}/lib"
          '';

          dotnetPkg =
            (with dotnetCorePackages; combinePackages [
              sdk_6_0
              sdk_7_0
              sdk_8_0
            ]);

          deps = [
            dotnetPkg
            omnisharp-roslyn
            fsautocomplete
          ];

          DOTNET_ROOT = "${dotnetPkg}";

          NIX_LD_LIBRARY_PATH = lib.makeLibraryPath ([
            stdenv.cc.cc
          ] ++ deps);
          NIX_LD = "${stdenv.cc.libc_bin}/bin/ld.so";
        };

        # For compatibility with older versions of the `nix` binary
        devShell = self.devShells.${system}.default;
      }
    );
}
