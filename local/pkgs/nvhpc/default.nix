{
  stdenvNoCC, fetchurl,
  gcc, gfortran, autoPatchelfHook,
  flock, glibc, coreutils, util-linux, iconv
}:
stdenvNoCC.mkDerivation rec
{
  pname = "nvhpc";
  version = "24.1";
  src = let versions = builtins.splitVersion version; in fetchurl
  {
    url = "https://developer.download.nvidia.com/hpc-sdk/${version}/"
      + "nvhpc_20${builtins.elemAt versions 0}_${builtins.concatStringsSep "" versions}"
      + "_Linux_x86_64_cuda_multi.tar.gz";
    sha256 = "1n0x1x7ywvr3623ylvrjagayn44mbvfas3c3062p7y3asmgjx697";
  };
  BuildInputs = [ gfortran gfortran.cc gcc ];
  propagatedBuildInputs = BuildInputs;
  nativeBuildInputs =
  [
    autoPatchelfHook flock
    glibc.bin # ldconfig
    coreutils # chmod
    util-linux # rev
  ];
  postUnpack = ''patchShebangs .'';
  dontBuild = true;
  dontStrip = true;
  NVHPC_SILENT = "true";
  NVHPC_INSTALL_TYPE = "single";
  installPhase =
  ''
    export NVHPC_INSTALL_DIR=$out/share/nvhpc
    ldconfig -C $NIX_BUILD_TOP/ld.so.cache
    sed -i 's|/bin/chmod|chmod|g' install_components/install
    sed -i 's|/sbin/ldconfig|ldconfig -C $NIX_BUILD_TOP/ld.so.cache|g' install_components/install
    sed -i 's|/usr/lib/x86_64-linux-gnu|${iconv.out}/lib|g' \
      install_components/Linux_x86_64/${version}/compilers/bin/makelocalrc
    ./install
  '';
  autoPatchelfIgnoreMissingDeps = [ "*" ];
}
