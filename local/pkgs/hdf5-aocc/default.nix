{
  buildFHSEnv, writeScript, stdenvNoCC,
  src,
  aocc, cmake
}:
let
  buildEnv = buildFHSEnv
  {
    name = "buildEnv";
    targetPkgs = pkgs: with pkgs; [ zlib aocc gcc.cc gcc.cc.lib mpi glibc.dev binutils.bintools ];
    extraBwrapArgs = [ "--bind" "$out" "$out" ];
  };
  buildScript = writeScript "build"
  ''
    mkdir build
    cd build
    cmake -DCMAKE_INSTALL_PREFIX=$out -DHDF5_INSTALL_CMAKE_DIR=$out/lib/cmake \
      -DHDF5_BUILD_FORTRAN=ON -DHDF5_ENABLE_PARALLEL=ON -DBUILD_SHARED_LIBS=OFF ..
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
  buildPhase =
  ''
    mkdir -p $out
    ${buildEnv}/bin/buildEnv ${buildScript}
  '';
  dontInstall = true;
  dontFixup = true;
  requiredSystemFeatures = [ "gccarch-exact-${stdenvNoCC.hostPlatform.gcc.arch}" "big-parallel" ];
}
