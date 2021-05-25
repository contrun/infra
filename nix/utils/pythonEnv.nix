with import <nixpkgs> {};
with python3Packages;

stdenv.mkDerivation {
  name = "impurePythonEnv";

  src = null;

  buildInputs = [
    # these packages are required for virtualenv and pip to work:
    #
    python3Full
    python3Packages.virtualenv
    python3Packages.pip
    # the following packages are related to the dependencies of your python
    # project.
    # In this particular example the python modules listed in the
    # requirements.txt require the following packages to be installed locally
    # in order to compile any binary extensions they may require.
    #
    taglib
    sqlite
    openssl
    redis
    git
    libxml2
    libzip
    stdenv
    zlib
  ];

  shellHook = ''
    # set SOURCE_DATE_EPOCH so that we can use python wheels
    SOURCE_DATE_EPOCH=$(date +%s)
    virtualenv --no-setuptools venv
    export PATH=$PWD/venv/bin:$PATH
    export PYTHONPATH=$PYTHONPATH:$PWD
  '';
}
