{
  stdenvNoCC, fetchurl, gcc, gfortran
}:
stdenvNoCC.mkDerivation rec
{
  pname = "nvhpc-sdk";
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
  postUnpack = ''patchShebangs . '';
  dontBuild = true;
  NVHPC_SILENT = "true";
  NVHPC_INSTALL_TYPE = "single";
  installPhase =
  ''
    export NVHPC_INSTALL_DIR=$out/share/nvhpc-sdk
    ./install
  '';
}
