{
  buildFHSEnv, writeScript, stdenvNoCC, requireFile, substituteAll,
  config, cudaCapabilities ? config.cudaCapabilities, nvhpcArch ? config.nvhpcArch or "px", additionalCommands ? "",
  nvhpc, lmod, mkl, gfortran, rsync, which, hdf5, wannier90, coreutils, zlib
}:
let
  sources = import ../source.nix { inherit requireFile; };
  buildEnv = buildFHSEnv
  {
    name = "buildEnv";
    targetPkgs = _: [ zlib ];
  };
  buildScript = writeScript "build"
  ''
    . ${lmod}/share/lmod/lmod/init/bash
    module use ${nvhpc}/share/nvhpc/modulefiles
    module load nvhpc
    mkdir -p bin
    make DEPS=1 -j$NIX_BUILD_CORES
  '';
  include = version: substituteAll
  {
    src = ./makefile.include-${version};
    cudaCapabilities = builtins.concatStringsSep "," (builtins.map
      (cap: "cc${builtins.replaceStrings ["."] [""] cap}")
      cudaCapabilities);
    inherit nvhpcArch;
  };
  vasp = version: stdenvNoCC.mkDerivation rec
  {
    pname = "vasp-nvidia";
    inherit version;
    src = sources.${version};
    configurePhase =
    ''
      cp ${include version} makefile.include
      cp ${../constr_cell_relax.F} src/constr_cell_relax.F
    '';
    enableParallelBuilding = true;
    buildInputs = [ mkl hdf5 wannier90 ];
    nativeBuildInputs = [ gfortran rsync which ];
    MKLROOT = mkl;
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
  startScript = version: writeScript "vasp-nvidia-${version}"
  ''
    . ${lmod}/share/lmod/lmod/init/bash
    module use ${nvhpc}/share/nvhpc/modulefiles
    module load nvhpc

    # if OMP_NUM_THREADS is not set, set it according to SLURM_CPUS_PER_TASK or to 1
    if [ -z "''${OMP_NUM_THREADS-}" ]; then
      if [ -n "''${SLURM_CPUS_PER_TASK-}" ]; then
        OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
      else
        OMP_NUM_THREADS=1
      fi
    fi
    export OMP_NUM_THREADS

    ${additionalCommands}

    variant=$(${coreutils}/bin/basename $0 | ${coreutils}/bin/cut -d- -f4)
    if [ -z "$variant" ]; then
      variant=std
    fi
    if [ "$variant" = "env" ]; then
      exec "$@"
    else if [ -n "''${SLURM_JOB_ID-}" ]; then
      # srun should be in PATH
      exec mpirun ${vasp version}/bin/vasp-$variant
    else
      exec mpirun -np 1 ${vasp version}/bin/vasp-$variant
    fi

    exec "$@"
  '';
  runEnv = version: let shortVersion = builtins.replaceStrings ["."] [""] version; in buildFHSEnv
  {
    name = "vasp-nvidia-${shortVersion}";
    targetPkgs = _: [ zlib (vasp version) ];
    runScript = startScript version;
    extraInstallCommands =
    ''
      pushd $out/bin
        for i in std gam ncl env; do ln -s vasp-intel-${shortVersion} vasp-intel-${shortVersion}-$i; done
      popd
    '';
  };
in builtins.mapAttrs (version: _: runEnv version) sources
