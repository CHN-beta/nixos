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
    buildPhase = "${buildEnv}/bin/buildEnv ${buildScript}";
    installPhase =
    ''
      mkdir -p $out/bin
      for i in std gam ncl; do cp bin/vasp_$i $out/bin/vasp-$i; done
    '';
    dontFixup = true;
    requiredSystemFeatures = [ "gccarch-exact-${stdenvNoCC.hostPlatform.gcc.arch}" "big-parallel" ];
  };
  startScript = version: writeScript "vasp-intel-${version}"
  ''
    . ${lmod}/share/lmod/lmod/init/bash
    module use ${oneapi}/share/intel/modulefiles
    module load tbb compiler-rt oclfpga # dependencies
    module load mpi mkl compiler

    # if SLURM_CPUS_PER_TASK is set, use it to set OMP_NUM_THREADS
    if [ -n "''${SLURM_CPUS_PER_TASK-}" ]; then
      export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
    fi

    exec "$@"
  '';
  runEnv = version: buildFHSEnv
  {
    name = "vasp-intel-${version}";
    targetPkgs = pkgs: with pkgs; [ zlib (vasp version) (writeTextDir "etc/release" "") gccFull ];
    runScript = startScript version;
    extraInstallCommands =
      "for i in std gam ncl; do ln -s ${vasp version}/bin/vasp-$i $out/bin/vasp-intel-${version}-$i; done";
  };
in builtins.mapAttrs (version: _: runEnv version) sources
