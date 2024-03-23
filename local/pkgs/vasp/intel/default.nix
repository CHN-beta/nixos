{
  buildFHSEnv, writeScript, stdenvNoCC, requireFile, substituteAll, symlinkJoin, writeTextDir,
  config, oneapiArch ? config.oneapiArch or "SSE3", additionalCommands ? "",
  oneapi, gcc, glibc, lmod, rsync, which, wannier90, binutils, hdf5, coreutils, slurm, zlib
}:
let
  sources = import ../source.nix { inherit requireFile; };
  buildEnv = buildFHSEnv
  {
    name = "buildEnv";
    # make "module load mpi" success
    targetPkgs = _: [ zlib (writeTextDir "etc/release" "") gccFull ];
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

    # if OMP_NUM_THREADS is not set, set it according to SLURM_CPUS_PER_TASK or to 1
    if [ -z "''${OMP_NUM_THREADS-}" ]; then
      if [ -n "''${SLURM_CPUS_PER_TASK-}" ]; then
        OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
      else
        OMP_NUM_THREADS=1
      fi
    fi
    export OMP_NUM_THREADS

    # if I_MPI_PIN_PROCESSOR_LIST is not set and SLURM_JOB_ID is not set, set it to allcores
    if [ -z "''${I_MPI_PIN_PROCESSOR_LIST-}" ] && [ -z "''${SLURM_JOB_ID-}" ]; then
      I_MPI_PIN_PROCESSOR_LIST=allcores
    fi
    export I_MPI_PIN_PROCESSOR_LIST

    # if I_MPI_PMI_LIBRARY is not set and SLURM_JOB_ID is set, set it to libpmi2.so
    if [ -z "''${I_MPI_PMI_LIBRARY-}" ] && [ -n "''${SLURM_JOB_ID-}" ]; then
      I_MPI_PMI_LIBRARY=${slurm}/lib/libpmi2.so
    fi
    export I_MPI_PMI_LIBRARY

    # set I_MPI_PIN I_MPI_PIN_DOMAIN I_MPI_DEBUG if not set
    export I_MPI_PIN=''${I_MPI_PIN-yes}
    export I_MPI_PIN_DOMAIN=''${I_MPI_PIN_DOMAIN-omp}
    export I_MPI_DEBUG=''${I_MPI_DEBUG-4}

    ${additionalCommands}

    # guess command we want to run

    variant=$(${coreutils}/bin/basename $0 | ${coreutils}/bin/cut -d- -f4)
    if [ -z "$variant" ]; then
      variant=std
    fi
    if [ "$variant" = "env" ]; then
      exec "$@"
    else if [ -n "''${SLURM_JOB_ID-}" ]; then
      # srun should be in PATH
      exec srun --mpi=pmi2 ${vasp version}/bin/vasp-$variant
    else
      exec mpirun -n 1 ${vasp version}/bin/vasp-$variant
    fi

    exec "$@"
  '';
  runEnv = version: let shortVersion = builtins.replaceStrings ["."] [""] version; in buildFHSEnv
  {
    name = "vasp-intel-${shortVersion}";
    targetPkgs = _: [ zlib (vasp version) (writeTextDir "etc/release" "") gccFull ];
    runScript = startScript version;
    extraInstallCommands =
    ''
      pushd $out/bin
        for i in std gam ncl env; do ln -s vasp-intel-${shortVersion} vasp-intel-${shortVersion}-$i; done
      popd
    '';
  };
in builtins.mapAttrs (version: _: runEnv version) sources
