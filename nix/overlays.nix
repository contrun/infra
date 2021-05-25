{ config, pkgs, inputs, ... }: {
  nixpkgs.overlays = let
    haskellOverlay = self: super:
      let
        originalCompiler = super.haskell.compiler;
        newCompiler = super.callPackages inputs.old-ghc-nix { pkgs = super; };
      in {
        haskell = super.haskell // {
          inherit originalCompiler newCompiler;
          compiler = newCompiler // originalCompiler;
        };
      };

    mozillaOverlay = import inputs.nixpkgs-mozilla;

    dontCheckOverlay = self: super:
      let
        overridePythonPackages = let
          packagesToIgnoreTest = [
            # "psutil" "pathpy"
          ];
          dontCheckPythonPkg = pp:
            pp.overridePythonAttrs (old: { doCheck = false; });
        in pythonPkg:
        pythonPkg.override {
          packageOverrides = pythonSelf: pythonSuper:
            super.lib.genAttrs packagesToIgnoreTest
            (name: dontCheckPythonPkg pythonSuper.${name});
        };
        dontCheckPkg = pkg: pkg.overrideAttrs (old: { doCheck = false; });
      in {
        python3Full = overridePythonPackages super.python3Full;
        python3 = overridePythonPackages super.python3;
      } // (super.lib.mapAttrs (name: p: dontCheckPkg p) { });

    shellsOverlay = self: super: {
      # This env is used to setup LD_LIBRARY_PATH appropirately in nix-shell
      # e.g. nix-shell -p zlib my-add-ld-library-path --run 'echo "$LD_LIBRARY_PATH"'
      my-add-ld-library-path = super.stdenv.mkDerivation {
        name = "my-add-ld-library-path";
        phases = [ "fixupPhase" ];
        setupHook = super.writeText "setupHook.sh" ''
          addLdLibraryPath() {
            addToSearchPath LD_LIBRARY_PATH $1/lib
          }

          addEnvHooks "$targetOffset" addLdLibraryPath
          echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
        '';
      };

      my-drop-into-build-shell = super.stdenv.mkDerivation {
        # Copied from https://discourse.nixos.org/t/nix-shell-and-output-path/4043/5
        # Usage: nix-shell -E 'with import <nixpkgs> {}; hello.overrideAttrs ({ nativeBuildInputs ? [], ...} : { nativeBuildInputs = nativeBuildInputs ++ [ dropIntoBuildShellHook ]; })'
        name = "my-drop-into-build-shell";
        phases = [ "fixupPhase" ];
        setupHook = super.writeText "setupHook.sh" ''
          dropIntoBuildShell() {
            if [[ -v "NIX_SET_LOCAL_OUTPUTS" ]] && [[ "$NIX_SET_LOCAL_OUTPUTS" ]]; then
              return
            fi

            # Note: we override TMPDIR to avoid auditTmpdir failure
            # (outputs cannot be children of "$TMPDIR")
            export base="$(mktemp -t -d "build-$name.XXXXXXXXXX")"
            export TMPDIR="$base/tmpdir"
            mkdir -p "$TMPDIR"

            echo "dropIntoBuildShell: settings outputs in $base directory"
            for output in $outputs; do
              export "$output"="$base/$output"
            done

            echo "dropIntoBuildShell: moving to $TMPDIR"
            cd "$TMPDIR"

            echo "dropIntoBuildShell: will automatically run genericBuild"
            export shellHook+=" genericBuild"

            export NIX_SET_LOCAL_OUTPUTS=1
          }
          addEnvHooks "$hostOffset" dropIntoBuildShell
        '';
      };

      # Usage: nix-shell -E 'with import <nixpkgs> {}; myDropIntoBuildShell hello'
      myDropIntoBuildShell = pkg:
        pkg.overrideAttrs ({ nativeBuildInputs ? [ ], ... }: {
          nativeBuildInputs = nativeBuildInputs
            ++ [ self.my-drop-into-build-shell ];
        });

      myBuildEnv = super.stdenv.mkDerivation {
        name = "my-build-env";
        nativeBuildInputs = [ super.pkg-config ];
        phases = [ "fixupPhase" ];
        setupHook = super.writeText "setupHook.sh" ''
          addPkgConfigPath() {
                  addToSearchPath PKG_CONFIG_PATH $1/lib/pkgconfig
                  addToSearchPath PKG_CONFIG_PATH $1/share/pkgconfig
          }

          addLdLibraryPath() {
                  addToSearchPath LD_LIBRARY_PATH $1/lib
          }

          addEnvHooks "$targetOffset" addLdLibraryPath
          addEnvHooks "$targetOffset" addPkgConfigPath
          # echo "PKG_CONFIG_PATH=$PKG_CONFIG_PATH"
          # echo "LD_LIBRARY_PATH=$LD_LIBRARY_PATH"
        '';
      };

      myRustDevEnvFn = let
        defaultMozillaOverlay = import (builtins.fetchTarball
          "https://github.com/mozilla/nixpkgs-mozilla/archive/master.tar.gz");
      in { pkgsPath ? <nixpkgs>, mozillaOverlay ? defaultMozillaOverlay
      , crossSystem ? null, channel ? "nightly" }:
      let
        pkgs = import pkgsPath {
          inherit crossSystem;
          overlays = [ mozillaOverlay ];
        };
        targets =
          [ pkgs.stdenv.targetPlatform.config "wasm32-unknown-unknown" ];
        myBuildPackageRust =
          pkgs.buildPackages.buildPackages.latest.rustChannels."${channel}".rust.override {
            inherit targets;
          };
        myRust =
          pkgs.rustChannels."${channel}".rust.override { inherit targets; };
      in with pkgs;
      let my_static_openssl = openssl.override { static = true; };
      in stdenv.mkDerivation {
        name = "my-rust-dev-env";
        # build time dependencies targeting the build platform
        depsBuildBuild = [ buildPackages.stdenv.cc ];
        HOST_CC = "cc";
        OPENSSL_LIB_DIR = "${my_static_openssl.out}/lib";
        OPENSSL_STATIC = "yes";
        OPENSSL_LIBRARIES = "${my_static_openssl.out}/lib";
        OPENSSL_INCLUDE_DIR = "${my_static_openssl.dev}/include";
        # build time dependencies targeting the host platform
        nativeBuildInputs =
          [ llvmPackages.libclang stdenv.cc.cc.lib pkgconfig ];
        buildInputs = [
          stdenv.cc.cc.lib
          libgcc
          llvmPackages.libclang
          llvmPackages.libstdcxxClang
          pkgconfig
          rocksdb
          my_static_openssl
          my_static_openssl.dev
          protobuf
          myRust
        ];
        CARGO_BUILD_TARGET = [ pkgs.stdenv.targetPlatform.config ];

        # run time dependencies
        LIBCLANG_PATH = "${llvmPackages.libclang}/lib";
        RUST_BACKTRACE = "full";
        PROTOC = "${protobuf}/bin/protoc";
      };

      myRustDevEnv = { ... }@args:
        self.myRustDevEnvFn args // {
          mozillaOverlay = mozillaOverlay;
        };
    };

    isInList = a: list: builtins.foldl' (acc: x: x == a || acc) false list;

    uniqueList = list:
      if list == [ ] then
        [ ]
      else
        let x = builtins.head list;
        in [ x ] ++ uniqueList (builtins.filter (e: e != x) list);

    recursivelyOverrideOutputsToInstall = attr:
      if builtins.isAttrs attr && attr ? meta && attr ? overrideAttrs then
        overrideOutputsToInstall attr [ "dev" ]
      else if builtins.isAttrs attr then
        builtins.mapAttrs (name: drv: recursivelyOverrideOutputsToInstall drv)
        attr
      else
        attr;

    overrideOutputsToInstall = attr: outputs:
      if !(builtins.isAttrs attr && attr ? meta && attr ? overrideAttrs && attr
        ? outputs) then
        attr
      else
        let
          myOutputsToInstall =
            builtins.filter (x: isInList x attr.outputs) outputs;
          oldOutputsToInstall = if attr.meta ? outputsToInstall then
            attr.meta.outputsToInstall
          else
            [ ];
          newOutputsToInstall =
            uniqueList (oldOutputsToInstall ++ myOutputsToInstall);
          newMeta = attr.meta // { outputsToInstall = newOutputsToInstall; };
        in attr.overrideAttrs (oldAttrs: { meta = newMeta; });

    myOverlay = self: super: {
      myPackages = let
        getHaskellPackages = haskellPackages:
          let allPackages = allHaskellPackages haskellPackages;
          in super.lib.flatten (super.lib.attrValues allPackages);

        allHaskellPackages = haskellPackages:
          with haskellPackages; rec {
            binaries = [
              # stylish-haskell
              # hindent
              # floskell
              # hfmt
              # brittany
              hoogle
              # stack2nix
            ];
            libraries = [
              zlib
              classy-prelude
              lens
              aeson
              servant
              yesod
              yesod-form
              yesod-auth
              # mighttpd2
              warp-tls
              # postgrest
              optparse-applicative
              optparse-simple
              optparse-generic
              # hw-prim
              QuickCheck
              attoparsec
              # bloodhound
              texmath
              # sbv
              vty
              pandoc-types
              proto-lens
              # proto-lens-optparse
              pipes
              network
              http-client
              text
              # propellor
              # esqueleto
              postgresql-simple
              persistent
              # persistent-postgresql
              persistent-sqlite
              microlens
              dhall
              monad-logger
              mtl
              semigroups
              comonad
              vector
              # massiv
              profunctors
              hashable
              unordered-containers
              HUnit
              hspec
              diagrams
              conduit
              conduit-extra
              # arbtt
            ];
            misc = [ hvega formatting ];
          };

        getPython3Packages = ps:
          with ps; [
            pip
            # chardet
            dateutil
            setuptools
            virtualenvwrapper
            pycparser
            pynvim
            pyparsing
            # requests
            docopt
            # python-dotenv
            pyyaml
            pyperclip
            # pyspark
            # matplotlib
            # plotly
            # altair
            # bokeh
            # vega
            # vega_datasets
            # numpy
            # pandas
            # scipy
            # arrow
            # subliminal
            lxml
            # cookiecutter
          ];
        makeEmacsPkg = emacsPkg:
          (super.emacsPackagesGen emacsPkg).emacsWithPackages (epkgs:
            [
              super.mu
              # super.notmuch
            ]);
      in rec {
        aspell = with super;
          aspellWithDicts (ps: with ps; [ en fr de en-science en-computers ]);

        hunspell = with super;
          hunspellWithDicts (with hunspellDicts; [ en-us fr-any de-de ]);

        xmonad = super.xmonad-with-packages.override {
          packages = haskellPackages:
            with haskellPackages; [
              xmobar
              taffybar
              xmonad-contrib
              xmonad-extras
              xmonad-utils
              # xmonad-windownames
              xmonad-entryhelper
              yeganesh
              libmpd
              dbus
            ];
        };

        haskell = super.haskellPackages.ghcWithPackages getHaskellPackages;

        idris = super.idrisPackages.with-packages (with super.idrisPackages; [
          base
          effects
          contrib
          pruviloj
          lightyear
          protobuf
        ]);

        aioproxy = inputs.aioproxy.defaultPackage.${super.system};

        lua = super.lua.withPackages
          (ps: with ps; [ busted luafilesystem luarocks lua-lsp nvim-client ]);

        jupyterhub = (super.python3.withPackages
          (p: with p; [ jupyterhub jupyterhub-systemdspawner ]));
        jupyterlab =
          (super.python3.withPackages (p: with p; [ jupyterhub jupyterlab ]));

        ruby = super.ruby_2_7.withPackages (ps:
          with ps; [
            rake
            rails
            rspec
            pry
            pry-byebug
            pry-doc
            rubocop
            rubocop-performance
          ]);

        vscode = let
          extensions = (with super.vscode-extensions; [
            bbenoist.Nix
            ms-python.python
            ms-azuretools.vscode-docker
            ms-vscode-remote.remote-ssh
            matklad.rust-analyzer
            # haskell.haskell
            james-yu.latex-workshop
            ms-kubernetes-tools.vscode-kubernetes-tools
            # ms-vscode.Go
            scala-lang.scala
            scalameta.metals
          ]);
        in super.vscode-with-extensions.override {
          vscodeExtensions = extensions;
        };

        pythonPackages = super.python3Packages;

        python = super.python3Full.withPackages getPython3Packages;

        python2 = with super;
          python2Full.withPackages
          (ps: with ps; [ pip setuptools sortedcontainers pycparser pyyaml ]);

        texLive = self.texlive.combine { inherit (self.texlive) scheme-full; };

        # emacs = makeEmacsPkg super.emacsGit;
        emacs = makeEmacsPkg super.emacs;

        emacsStable = makeEmacsPkg super.emacs;

        emacsGit = makeEmacsPkg super.emacsGit;

        emacsUnstable = makeEmacsPkg super.emacsUnstable;

        nvimdiff = with super;
          writeScriptBin "nvimdiff" ''
            #! ${stdenv.shell}
            exec ${neovim}/bin/nvim -d "$@"
          '';

        almond = let
          scalaVersion = "2.12.8";
          almondVersion = "0.10.8";
        in super.runCommand "almond" {
          nativeBuildInputs = [ self.coursier ];
        } ''
          mkdir -p $out/bin
          coursier bootstrap \
              --cache "$PWD"
              -r jitpack \
              -i user -I user:sh.almond:scala-kernel-api_${scalaVersion}:${almondVersion} \
              sh.almond:scala-kernel_${scalaVersion}:${almondVersion} \
              -o $out/bin/almond
        '';

        kodi = super.kodi;

        ugdb = with self;
          with rustPlatform; {
            ugdb = buildRustPackage rec {
              pname = "ugdb";
              version = "0.1.4";

              src = fetchFromGitHub {
                owner = "ftilde";
                repo = pname;
                rev = version;
                sha256 = "0521x40f8clzg4g1gdf30mb7cnyrmripifssvdprgi51dcnblnyz";
              };

              cargoSha256 =
                "0bndhj441znd46ms7as66bi3ilr0glvi0wmj47spak90s97w67ci";
              nativeBuildInputs = [ pkgconfig ];
              buildInputs = [ openssl libgit2 ];
              LIBGIT2_SYS_USE_PKG_CONFIG = true;
            };
          };

        authinfo = with super;
          stdenv.mkDerivation rec {
            version = "HEAD";
            pname = "authinfo";
            src = inputs.authinfo;

            buildInputs = [ gpgme libassuan python ];
            nativeBuildInputs = [ autoreconfHook pkgconfig ];

            meta = with stdenv.lib; {
              description = "KISS password manager";
              homepage = "https://github.com/aartamonau/authinfo";
              platforms = platforms.all;
            };
          };

        # https://github.com/LnL7/dotfiles/blob/master/nixpkgs/pkgs/elixir-ls/default.nix
        elixir-ls = with super;
          stdenv.mkDerivation rec {
            name = "elixir-ls-${version}";
            version = "0.2.24";
            src = fetchurl {
              url =
                "https://github.com/JakeBecker/elixir-ls/releases/download/v${version}/elixir-ls.zip";
              sha256 = "0p0fnsqcm0572cgzzyki7i5wvhsa6hx7a9zw1jrgwczhcgvmgpab";
            };

            nativeBuildInputs = [ makeWrapper unzip ];

            unpackPhase = ''
              unzip -d elixir-ls $src
            '';

            installPhase = ''
              mkdir -p $out/bin $out/libexec
              cp -r elixir-ls $out/libexec
              chmod +x $out/libexec/elixir-ls/language_server.sh
              makeWrapper $out/libexec/elixir-ls/language_server.sh $out/bin/elixir-ls \
                  --suffix PATH ":" "${elixir}/bin"
              makeWrapper $out/libexec/elixir-ls/language_server.sh $out/bin/language_server.sh \
                  --suffix PATH ":" "${elixir}/bin"
            '';

            meta = with stdenv.lib; {
              description = "A language server for Elixir";
              # license = stdenv.lib.licenses.unspecified;
              homepage = "https://github.com/JakeBecker/elixir-ls";
              platforms = platforms.unix;
            };
          };
      } // super.lib.optionalAttrs
      (inputs.flake-firefox-nightly.packages ? "${super.system}") {
        firefox =
          inputs.flake-firefox-nightly.packages."${super.system}".firefox-nightly-bin;
      };
    };

  in [
    mozillaOverlay
    haskellOverlay
    dontCheckOverlay
    inputs.emacs-overlay.overlay
    myOverlay
    shellsOverlay
  ];
}
