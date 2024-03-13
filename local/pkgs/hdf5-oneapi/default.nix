{
  buildFHSEnv, writeScript, stdenvNoCC, symlinkJoin,
  src,
  oneapi, lmod, cmake, gcc, glibc, binutils,
  config, oneapiArch ? config.oneapiArch or "SSE3"
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
  # somehow make it build failed, currently remove it
  # CFLAGS = "-x${oneapiArch}";
  # CXXFLAGS = "-x${oneapiArch}";
  # FFLAGS = "-x${oneapiArch}";
  I_MPI_CC = "icx";
  I_MPI_CXX = "icpx";
  I_MPI_FC = "ifx";
  I_MPI_F90 = "ifx";
  buildPhase =
  ''
    mkdir -p $out
    ${buildEnv}/bin/buildEnv ${buildScript}
  '';
  dontInstall = true;
  dontFixup = true;
  requiredSystemFeatures = [ "gccarch-exact-${stdenvNoCC.hostPlatform.gcc.arch}" "big-parallel" ];
}
