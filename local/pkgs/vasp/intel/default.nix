{
  buildFHSEnv, writeScript, stdenvNoCC, requireFile, substituteAll, symlinkJoin,
  config, oneapiArch ? config.oneapiArch or "SSE3",
  oneapi, gcc, glibc, lmod, rsync, which, wannier90, binutils, hdf5
}:
let
  sources = import ../source.nix { inherit requireFile; };
  buildEnv = buildFHSEnv
  {
    name = "buildEnv";
    # make "module load mpi" success
    targetPkgs = pkgs: with pkgs; [ zlib (writeTextDir "etc/release" "") gccFull ];
  };
  buildScript = writeScript "build"
  ''
    . ${lmod}/share/lmod/lmod/init/bash
    module use ${oneapi}/share/intel/modulefiles
    module load tbb compiler-rt oclfpga # dependencies
    module load mpi mkl compiler
    mkdir -p bin
    make DEPS=1 -j$NIX_BUILD_CORES
  '';
  include = version: substituteAll
  {
    src = ./makefile.include-${version};
    inherit oneapiArch;
  };
  gccFull = symlinkJoin { name = "gcc"; paths = [ gcc gcc.cc gcc.cc.lib glibc.dev binutils.bintools ]; };
  vasp = version: stdenvNoCC.mkDerivation rec
  {
    pname = "vasp-intel";
    inherit version;
    src = sources.${version};
    configurePhase =
    ''
      cp ${include version} makefile.include
      cp ${../constr_cell_relax.F} src/constr_cell_relax.F
    '';
    nativeBuildInputs = [ rsync which ];
    HDF5_ROOT = hdf5;
    WANNIER90_ROOT = wannier90;
    I_MPI_F90 = "ifx";
    buildPhase = "${buildEnv}/bin/buildEnv ${buildScript}";
    installPhase =
    ''
      mkdir -p $out/bin
      for i in std gam ncl; do cp bin/vasp_$i $out/bin/vasp-$i; done
    '';
    requiredSystemFeatures = [ "gccarch-exact-${stdenvNoCC.hostPlatform.gcc.arch}" "big-parallel" ];
  };
  startScript = version: writeScript "vasp-intel-${version}"
  ''
    . ${lmod}/share/lmod/lmod/init/bash
    module use ${oneapi}/share/intel/modulefiles
    module load tbb compiler-rt oclfpga # dependencies
    module load mpi mkl compiler
    exec "$@"
  '';
  runEnv = version: buildFHSEnv
  {
    name = "vasp-intel-${version}";
    targetPkgs = pkgs: with pkgs; [ zlib (vasp version) (writeTextDir "etc/release" "") ];
    runScript = startScript version;
  };
in builtins.mapAttrs (version: _: runEnv version) sources
