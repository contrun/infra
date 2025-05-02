{
  stdenvNoCC,
  stdenv,
  lib,
  fetchurl,
  dpkg,
  nss,
  nspr,
  xorg,
  pango,
  zlib,
  atkmm,
  libdrm,
  libxkbcommon,
  xcbutilwm,
  xcbutilimage,
  xcbutilkeysyms,
  xcbutilrenderutil,
  mesa,
  alsa-lib,
  wayland,
  openssl_1_1,
  atk,
  qt6,
  at-spi2-atk,
  at-spi2-core,
  dbus,
  cups,
  gtk3,
  libxml2,
  cairo,
  freetype,
  fontconfig,
  vulkan-loader,
  gdk-pixbuf,
  libexif,
  ffmpeg,
  pulseaudio,
  systemd,
  libuuid,
  expat,
  bzip2,
  glib,
  libva,
  libGL,
  libnotify,
  buildFHSEnv,
  writeShellScript,
}:

let
  pname = "cmcc-jtydn";
  version = "2.8.10";

  debPkg = fetchurl {
    url = "https://dl.soho.komect.com/upgrade/download/app/13805f6372ac8bdd";
    sha256 = "19clnp7kmp6fmmma8lg1xnwf67zrm7gcawan7pb3269ihhrvwa88";
  };

  env = stdenvNoCC.mkDerivation {
    meta.priority = 1;
    name = "${pname}-env";
    buildCommand = ''
      mkdir -p $out/bin
      mkdir -p $out/opt
      mkdir -p $out/usr

      ln -s ${stdenv.shellPackage}/bin/bash $out/bin/bash
      ln -s ${pkg}/opt/* $out/opt/
      ln -s ${pkg}/usr/* $out/usr/
    '';
    preferLocalBuild = true;
  };

  runtime = with xorg; [
    stdenv.cc.cc
    stdenv.cc.libc
    pango
    zlib
    xcbutilwm
    xcbutilimage
    xcbutilkeysyms
    xcbutilrenderutil
    libX11
    libXt
    libXext
    libSM
    libICE
    libxcb
    libxkbcommon
    libxshmfence
    libXi
    libXft
    libXcursor
    libXfixes
    libXScrnSaver
    libXcomposite
    libXdamage
    libXtst
    libXrandr
    libnotify
    atk
    atkmm
    cairo
    at-spi2-atk
    at-spi2-core
    alsa-lib
    dbus
    cups
    gtk3
    gdk-pixbuf
    libexif
    ffmpeg
    libva
    freetype
    fontconfig
    libXrender
    libuuid
    expat
    glib
    nss
    nspr
    libGL
    libxml2
    pango
    libdrm
    mesa
    vulkan-loader
    systemd
    wayland
    pulseaudio
    qt6.qt5compat
    openssl_1_1
    bzip2
  ];

  pkg = stdenv.mkDerivation {
    inherit pname version;

    src = debPkg;

    nativeBuildInputs = [
      dpkg
    ];

    unpackPhase = ''
      mkdir -p $out
      dpkg-deb -x $src ./extracted
      sourceRoot=./extracted
    '';

    installPhase = ''
      mkdir -p $out/bin
      cp -r * $out
    '';
    meta = with lib; {
      description = "CMCC VDI Client";
      homepage = "https://soho.komect.com";
      license = licenses.unfree;
      platforms = platforms.linux;
      maintainers = [ ];
      mainProgram = "cmcc-jtydn";
    };
  };
in
buildFHSEnv {
  inherit (pkg) name meta;
  runScript = writeShellScript "${pname}-launcher" ''
    export QT_QPA_PLATFORM=xcb
    export LD_LIBRARY_PATH=${lib.makeLibraryPath runtime}
    ${pkg.outPath}/opt/chuanyun-vdi-client/launch-app.sh
  '';
  extraInstallCommands = ''
    mkdir -p $out/share/applications
    mkdir -p $out/share/icons
    cp -r ${pkg.outPath}/usr/share/applications/cmcc-jtydn.desktop $out/share/applications
    cp -r ${pkg.outPath}/usr/share/icons/* $out/share/icons/

    mv $out/bin/$name $out/bin/${pname}

    substituteInPlace $out/share/applications/cmcc-jtydn.desktop  \
      --replace-quiet 'Exec=/opt/chuanyun-vdi-client/cmcc-jtydn' "Exec=$out/bin/${pname} --"
  '';
  targetPkgs = pkgs: [ env ];

  extraOutputsToInstall = [
    "usr"
  ];
}
