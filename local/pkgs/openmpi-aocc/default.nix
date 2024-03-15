{
  lib, buildFHSEnv, writeScript, stdenvNoCC,
  openmpi, 
  aocc, cmake, libnl, pmix, libpsm2, libfabric, zlib, numactl, ucx, ucc, libevent, hwloc, rdma-core, perl, glibc, binutils, gcc
}:
let
  buildEnv = buildFHSEnv
  {
    name = "buildEnv";
    targetPkgs = _: [ zlib aocc gcc.cc.lib.lib glibc.dev binutils.bintools libnl numactl ucx ucc libevent hwloc rdma-core libpsm2 libfabric perl ];
    extraBwrapArgs = [ "--bind" "$out" "$out" ];
  };
  buildScript = writeScript "build"
  ''
    ./configure --prefix=$out --disable-mca-dso
    make -j$NIX_BUILD_CORES
    make install
  '';
in stdenvNoCC.mkDerivation
{
  name = "openmpi-aocc";
  inherit (openmpi) src postPatch;
  dontConfigure = true;
  CC = "clang";
  CXX = "clang++";
  FC = "flang";
  OMPI_CC = "clang";
  OMPI_CXX = "clang++";
  OMPI_FC = "flang";
  CFLAGS = "-march=${stdenvNoCC.hostPlatform.gcc.arch} -O2";
  CXXFLAGS = "-march=${stdenvNoCC.hostPlatform.gcc.arch} -O2";
  FCFLAGS = "-march=${stdenvNoCC.hostPlatform.gcc.arch} -O2";
  enableParallelBuilding = true;
  buildPhase =
  ''
    runHook preBuild
    mkdir -p $out
    ${buildEnv}/bin/buildEnv ${buildScript}
    runHook postBuild
  '';
  postBuild = with openmpi; postInstall + postFixup;
  dontInstall = true;
  dontFixup = true;
  requiredSystemFeatures = [ "gccarch-exact-${stdenvNoCC.hostPlatform.gcc.arch}" "big-parallel" ];
}
