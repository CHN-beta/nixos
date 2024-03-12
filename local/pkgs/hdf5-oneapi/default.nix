{
  buildFHSEnv, writeScript, stdenvNoCC, symlinkJoin,
  src,
  oneapi, lmod, cmake, gcc, glibc, binutils,
  config, oneapiArch ? config.oneapiArch or "SSE3",
}:
let
  gccFull = symlinkJoin { name = "gcc"; paths = [ gcc gcc.cc gcc.cc.lib glibc.dev binutils.bintools ]; };
  buildEnv = buildFHSEnv
  {
    name = "buildEnv";
    targetPkgs = pkgs: with pkgs; [ zlib (writeTextDir "etc/release" "") gccFull ];
    extraBwrapArgs = [ "--bind" "$out" "$out" ];
  };
  buildScript = writeScript "build"
  ''
    . ${lmod}/share/lmod/lmod/init/bash
    module use ${oneapi}/share/intel/modulefiles
    module load tbb compiler-rt oclfpga # dependencies
    module load mpi mkl compiler
    mkdir build
    cd build
    cmake -DCMAKE_INSTALL_PREFIX=$out -DHDF5_INSTALL_CMAKE_DIR=$out/lib/cmake \
      -DHDF5_BUILD_FORTRAN=ON -DHDF5_ENABLE_PARALLEL=ON -DBUILD_SHARED_LIBS=OFF -DBUILD_STATIC_LIBS=OFF \
      -DCMAKE_C_COMPILER=icx -DCMAKE_CXX_COMPILER=icpx -DCMAKE_Fortran_COMPILER=ifort \
      -DBUILD_TESTING=OFF ..
    make -j$NIX_BUILD_CORES
    make install
  '';
in stdenvNoCC.mkDerivation
{
  name = "hdf5-oneapi";
  inherit src;
  dontConfigure = true;
  enableParallelBuilding = true;
  nativeBuildInputs = [ cmake ];
  CFLAGS = "-x${oneapiArch}";
  CXXFLAGS = "-x${oneapiArch}";
  FFLAGS = "-x${oneapiArch}"; # somehow make cmake failed
  buildPhase =
  ''
    mkdir -p $out
    ${buildEnv}/bin/buildEnv ${buildScript}
  '';
  dontInstall = true;
  requiredSystemFeatures = [ "gccarch-exact-${stdenvNoCC.hostPlatform.gcc.arch}" ];
}
