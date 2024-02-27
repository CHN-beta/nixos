{
  buildFHSEnv, writeScript, stdenvNoCC,
  src,
  nvhpc, lmod, cmake, gfortran,
  config, nvhpcArch ? config.nvhpcArch or "px"
}:
let
  buildEnv = buildFHSEnv
  {
    name = "buildEnv";
    targetPkgs = pkgs: with pkgs; [ zlib ];
    extraBwrapArgs = [ "--bind" "$out" "$out" ];
  };
  buildScript = writeScript "build"
  ''
    . ${lmod}/share/lmod/lmod/init/bash
    module use ${nvhpc}/share/nvhpc/modulefiles
    module load nvhpc
    mkdir build
    cd build
    cmake -DCMAKE_INSTALL_PREFIX=$out -DHDF5_INSTALL_CMAKE_DIR=$out/lib/cmake \
      -DHDF5_BUILD_FORTRAN=ON -DHDF5_ENABLE_PARALLEL=ON -DBUILD_SHARED_LIBS=ON ..
    make -j$NIX_BUILD_CORES
    make install
  '';
in stdenvNoCC.mkDerivation
{
  name = "hdf5-nvhpc";
  inherit src;
  dontConfigure = true;
  enableParallelBuilding = true;
  nativeBuildInputs = [ cmake gfortran ];
  buildPhase =
  ''
    mkdir -p $out
    ${buildEnv}/bin/buildEnv ${buildScript}
  '';
  dontInstall = true;
  requiredSystemFeatures = [ "nvhpcarch-${nvhpcArch}" ];
}
