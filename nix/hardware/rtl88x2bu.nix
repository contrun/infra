{ stdenv, fetchFromGitHub, kernel, bc, dnsmasq, hostapd}:
stdenv.mkDerivation rec {
  name = "rtl88x2bu-${kernel.version}-${version}";
  version = "5.6.1_30362.20181109_COEX20180928-6a6a";

  src = fetchFromGitHub {
    owner = "cilynx";
    repo = "rtl88x2bu";
    rev = "e8040efe1f17d360b36cded30a9dff3f283a2b93";
    sha256 = "00b2677q1i6lkjqq5ngk0wk4n5q3vh8bvxxfg2qv7z03p0shqhjk";
  };

  hardeningDisable = [ "pic" ];

  nativeBuildInputs = [ bc ];
  buildInputs = kernel.moduleBuildDependencies;

  prePatch = ''
    substituteInPlace ./Makefile \
      --replace /lib/modules/ "${kernel.dev}/lib/modules/" \
      --replace '$(shell uname -r)' "${kernel.modDirVersion}" \
      --replace /sbin/depmod \# \
      --replace '$(MODDESTDIR)' "$out/lib/modules/${kernel.modDirVersion}/kernel/net/wireless/"
  '';

  preInstall = ''
    mkdir -p "$out/lib/modules/${kernel.modDirVersion}/kernel/net/wireless/"
  '';

  meta = with stdenv.lib; {
    description = "Realtek rtl88x2bu driver";
    homepage = "https://github.com/cilynx/rtl88x2bu/";
    license = licenses.gpl2;
    platforms = platforms.linux;
    maintainers = [ maintainers.hhm ];
  };
}
