{ stdenv, fetchFromGitHub, kernel, bc, nukeReferences }:
stdenv.mkDerivation rec {
  name = "rtl8822bu-${kernel.version}-${version}";
  version = "f220c47cb7e7370ad95f84eff75395dced664be2";

  src = fetchFromGitHub {
    owner = "jeremyb31";
    repo = "rtl8822bu";
    rev = version;
    sha256 = "06vfihlrkw5a3h06k0y302kxd9cy566i7zd85aid580bfry1skxa";
  };

  hardeningDisable = [ "pic" ];

  nativeBuildInputs = [ bc nukeReferences ];
  buildInputs = kernel.moduleBuildDependencies;

  prePatch = ''
    substituteInPlace ./Makefile \
      --replace /lib/modules/ "${kernel.dev}/lib/modules/" \
      --replace '$(shell uname -r)' "${kernel.modDirVersion}" \
      --replace /sbin/depmod \# \
      --replace '$(MODDESTDIR)' "$out/lib/modules/${kernel.modDirVersion}/kernel/net/wireless/"
  '';

  makeFlags = [
    "ARCH=${stdenv.hostPlatform.platform.kernelArch}"
    "KSRC=${kernel.dev}/lib/modules/${kernel.modDirVersion}/build"
    ("CONFIG_PLATFORM_I386_PC=" + (if (stdenv.hostPlatform.isi686 || stdenv.hostPlatform.isx86_64) then "y" else "n"))
    ("CONFIG_PLATFORM_ARM_RPI=" + (if (stdenv.hostPlatform.isAarch32 || stdenv.hostPlatform.isAarch64) then "y" else "n"))
  ] ++ stdenv.lib.optional (stdenv.hostPlatform != stdenv.buildPlatform) [
    "CROSS_COMPILE=${stdenv.cc.targetPrefix}"
  ];

  preInstall = ''
    mkdir -p "$out/lib/modules/${kernel.modDirVersion}/kernel/net/wireless/"
  '';

  postInstall = ''
    nuke-refs $out/lib/modules/*/kernel/net/wireless/*.ko
  '';

  meta = with stdenv.lib; {
    description = "Realtek rtl8822bu driver";
    homepage = "https://github.com/jeremyb31/rtl8822bu/";
    license = licenses.gpl2;
    platforms = platforms.linux;
  };
}
