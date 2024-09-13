{
  buildFHSEnv, writeScript, stdenvNoCC, substituteAll, symlinkJoin, writeTextDir, src,
  config, oneapiArch ? config.oneapiArch or "SSE3",
  oneapi, gcc, glibc, lmod, rsync, which, wannier90, binutils, hdf5, zlib, vtst
}:
let
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
    make DEPS=1 -j$NIX_BUILD_CORES
  '';
  include = substituteAll { src = ./makefile.include; inherit oneapiArch; };
  gccFull = symlinkJoin { name = "gcc"; paths = [ gcc gcc.cc gcc.cc.lib glibc.dev binutils.bintools ]; };
  vasp = stdenvNoCC.mkDerivation
  {
    name = "vasp-intel";
    inherit src;
    # patches = [ ../vtst.patch ];
    configurePhase =
    ''
      cp ${include} makefile.include
      chmod +w makefile.include
      cp ${../constr_cell_relax.F} src/constr_cell_relax.F
      # cp -r ${vtst}/* src
      chmod -R +w src
    '';
    nativeBuildInputs = [ rsync which ];
    HDF5_ROOT = hdf5;
    WANNIER90_ROOT = wannier90;
    buildPhase = "${buildEnv}/bin/buildEnv ${buildScript}";
    installPhase =
    ''
      mkdir -p $out/bin
      for i in std gam ncl; do cp bin/vasp_$i $out/bin/vasp-$i; done
      mkdir $out/src
      ln -s ${src} $out/src/vasp
      ln -s ${vtst} $out/src/vtst
    '';
    dontFixup = true;
    requiredSystemFeatures = [ "gccarch-exact-${stdenvNoCC.hostPlatform.gcc.arch}" "big-parallel" ];
  };
  startScript = variant: writeScript "vasp-intel"
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

    # if I_MPI_PIN_PROCESSOR_LIST is not set, set it to allcores
    if [ -z "''${I_MPI_PIN_PROCESSOR_LIST-}" ]; then
      I_MPI_PIN_PROCESSOR_LIST=allcores
    fi
    export I_MPI_PIN_PROCESSOR_LIST

    # set I_MPI_PIN I_MPI_PIN_DOMAIN I_MPI_DEBUG if not set
    export I_MPI_PIN=''${I_MPI_PIN-yes}
    export I_MPI_PIN_DOMAIN=''${I_MPI_PIN_DOMAIN-omp}
    export I_MPI_DEBUG=''${I_MPI_DEBUG-4}

    # fork to bootstrap, do not use srun, causing it could not find proper ld
    export I_MPI_HYDRA_BOOTSTRAP=''${I_MPI_HYDRA_BOOTSTRAP-fork}

    # set OMP_STACKSIZE if not set
    export OMP_STACKSIZE=''${OMP_STACKSIZE-512M}

    ${
      if variant == "env" then ''exec "$@"''
      else
      ''
        if [ -n "''${SLURM_JOB_ID-}" ]; then
          exec mpirun -n $SLURM_NTASKS ${vasp}/bin/vasp-${variant}
        else
          exec mpirun -n 1 ${vasp}/bin/vasp-${variant}
        fi
      ''
    }
  '';
  runEnv = variant: buildFHSEnv
  {
    name = "vasp-intel${if variant == "" then "" else "-${variant}"}";
    targetPkgs = _: [ zlib vasp (writeTextDir "etc/release" "") gccFull ];
    runScript = startScript (if variant == "" then "std" else variant);
  };
in symlinkJoin
{
  name = "vasp-intel";
  paths = builtins.map (variant: runEnv variant) [ "" "env" "std" "gam" "ncl" ];
}
