{
  buildFHSEnv, writeScript, stdenvNoCC, requireFile, substituteAll, symlinkJoin,
  config, oneapiArch ? config.oneapiArch or "SSE3",
  oneapi, gfortran, gcc, glibc, lmod, rsync, which, hdf5, wannier90
}:
let
  versions = import ../source.nix;
  buildEnv = buildFHSEnv
  {
    name = "buildEnv";
    # make "module load mpi" success
    targetPkgs = pkgs: with pkgs; [ zlib (writeTextDir "etc/release" "") ];
  };
  buildScript = writeScript "build"
  ''
    . ${lmod}/share/lmod/lmod/init/bash
    module use ${oneapi}/share/intel/modulefiles
    module load tbb compiler-rt oclfpga # dependencies
    module load mpi mkl compiler
    mkdir -p bin
    make DEPS=1 -j$NIX_BUILD_CORES std
  '';
  include = version: substituteAll
  {
    src = ./makefile.include-${version};
    inherit oneapiArch;
    gcc = symlinkJoin { name = "gcc"; paths = [ gcc gcc.cc glibc.dev ]; };
  };
  vasp = version: stdenvNoCC.mkDerivation rec
  {
    pname = "vasp";
    inherit version;
    src = requireFile
    {
      name = "${pname}-${version}";
      sha256 = versions.${version};
      hashMode = "recursive";
      message = "Source file not found.";
    };
    configurePhase =
    ''
      cp ${include version} makefile.include
      cp ${../constr_cell_relax.F} src/constr_cell_relax.F
    '';
    enableParallelBuilding = false;
    buildInputs = [ hdf5 hdf5.dev wannier90 glibc.dev ];
    nativeBuildInputs = [ gfortran gfortran.cc gcc rsync which ];
    HDF5_ROOT = hdf5.dev;
    WANNIER90_ROOT = wannier90;
    buildPhase = "${buildEnv}/bin/buildEnv ${buildScript}";
    installPhase =
    ''
      mkdir -p $out/bin
      for i in std gam ncl; do cp bin/vasp_$i $out/bin/vasp-$i; done
    '';
  };
  startScript = version: writeScript "vasp-intel-${version}"
  ''
    . ${lmod}/share/lmod/lmod/init/bash
    module use ${oneapi}/share/intel/modulefiles
    module load tbb compiler-rt oclfpga # dependencies
    module load mpi mkl compiler
    exec $@
  '';
  runEnv = version: buildFHSEnv
  {
    name = "vasp-intel-${version}";
    targetPkgs = pkgs: with pkgs; [ zlib (vasp version) (writeTextDir "etc/release" "") ];
    runScript = startScript version;
  };
in builtins.mapAttrs (version: _: runEnv version) versions
