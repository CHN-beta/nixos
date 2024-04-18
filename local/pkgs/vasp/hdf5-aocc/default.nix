{
  buildFHSEnv, writeScript, stdenvNoCC,
  src,
  aocc, cmake, openmpi, zlib, gcc, glibc, binutils, pkg-config
}:
let
  buildEnv = buildFHSEnv
  {
    name = "buildEnv";
    targetPkgs = _: [ zlib aocc gcc.cc.lib.lib glibc.dev binutils.bintools openmpi pkg-config ];
    extraBwrapArgs = [ "--bind" "$out" "$out" ];
  };
  buildScript = writeScript "build"
  ''
    mkdir build
    cd build
    cmake -DCMAKE_INSTALL_PREFIX=$out -DHDF5_INSTALL_CMAKE_DIR=$out/lib/cmake \
      -DHDF5_BUILD_FORTRAN=ON -DHDF5_ENABLE_PARALLEL=ON ..
    make -j$NIX_BUILD_CORES
    make install
  '';
in stdenvNoCC.mkDerivation
{
  name = "hdf5-aocc";
  inherit src;
  dontConfigure = true;
  enableParallelBuilding = true;
  nativeBuildInputs = [ cmake ];
  CC = "clang";
  CXX = "clang++";
  FC = "flang";
  OMPI_CC = "clang";
  OMPI_CXX = "clang++";
  OMPI_FC = "flang";
  CFLAGS = "-march=${stdenvNoCC.hostPlatform.gcc.arch} -O2";
  CXXFLAGS = "-march=${stdenvNoCC.hostPlatform.gcc.arch} -O2";
  FCFLAGS = "-march=${stdenvNoCC.hostPlatform.gcc.arch} -O2";
  buildPhase =
  ''
    mkdir -p $out
    ${buildEnv}/bin/buildEnv ${buildScript}
  '';
  dontInstall = true;
  dontFixup = true;
  requiredSystemFeatures = [ "gccarch-exact-${stdenvNoCC.hostPlatform.gcc.arch}" ];
}
