{
  buildFHSEnv, writeScript, stdenvNoCC, substituteAll, symlinkJoin, src,
  config, cudaCapabilities ? config.cudaCapabilities, nvhpcArch ? config.nvhpcArch or "px",
  nvhpc, lmod, mkl, gfortran, rsync, which, hdf5, wannier90, zlib, vtst
}:
let
  buildEnv = buildFHSEnv { name = "buildEnv"; targetPkgs = _: [ zlib ]; };
  buildScript = writeScript "build"
  ''
    . ${lmod}/share/lmod/lmod/init/bash
    module use ${nvhpc}/share/nvhpc/modulefiles
    module load nvhpc
    make DEPS=1 -j$NIX_BUILD_CORES
  '';
  include = substituteAll
  {
    src = ./makefile.include;
    cudaCapabilities = builtins.concatStringsSep "," (builtins.map
      (cap: "cc${builtins.replaceStrings ["."] [""] cap}")
      cudaCapabilities);
    inherit nvhpcArch;
  };
  vasp = stdenvNoCC.mkDerivation
  {
    name = "vasp-nvidia";
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
      mkdir $out/src
      ln -s ${src} $out/src/vasp
      ln -s ${vtst} $out/src/vtst
    '';
    dontFixup = true;
    requiredSystemFeatures = [ "gccarch-exact-${stdenvNoCC.hostPlatform.gcc.arch}" "big-parallel" ];
  };
  startScript = variant: writeScript "vasp-nvidia"
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

    ${
      if variant == "env" then ''exec "$@"''
      else
      ''
        if [ -n "''${SLURM_JOB_ID-}" ]; then
          exec mpirun --bind-to none ${vasp}/bin/vasp-${variant}
        else
          exec mpirun -np 1 ${vasp}/bin/vasp-${variant}
        fi
      ''
    }
  '';
  runEnv = variant: buildFHSEnv
  {
    name = "vasp-nvidia${if variant == "" then "" else "-${variant}"}";
    targetPkgs = _: [ zlib vasp ];
    runScript = startScript (if variant == "" then "std" else variant);
  };
in symlinkJoin
  {
    name = "vasp-nvidia";
    paths = builtins.map (variant: runEnv variant) [ "" "env" "std" "gam" "ncl" ];
  }
