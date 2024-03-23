{
  buildFHSEnv, writeScript, stdenvNoCC, requireFile, substituteAll,
  aocc, rsync, which, hdf5, wannier90, aocl, openmpi, gcc, zlib, glibc, binutils, libpsm2,
  additionalCommands ? ""
}:
let
  sources = import ../source.nix { inherit requireFile; };
  buildEnv = buildFHSEnv
  {
    name = "buildEnv";
    targetPkgs = _: [ zlib aocc aocl openmpi gcc.cc gcc.cc.lib glibc.dev binutils.bintools ];
  };
  buildScript = writeScript "build"
  ''
    mkdir -p bin
    make DEPS=1 -j$NIX_BUILD_CORES
  '';
  include = version: substituteAll
  {
    src = ./makefile.include-${version};
    gccArch = stdenvNoCC.hostPlatform.gcc.arch;
  };
  vasp = version: stdenvNoCC.mkDerivation rec
  {
    pname = "vasp-amd";
    inherit version;
    src = sources.${version};
    configurePhase =
    ''
      cp ${include version} makefile.include
      cp ${../constr_cell_relax.F} src/constr_cell_relax.F
    '';
    buildInputs = [ wannier90 ];
    nativeBuildInputs = [ rsync which ];
    AMDBLIS_ROOT = aocl;
    AMDLIBFLAME_ROOT = aocl;
    AMDSCALAPACK_ROOT = aocl;
    AMDFFTW_ROOT = aocl;
    HDF5_ROOT = hdf5;
    WANNIER90_ROOT = wannier90;
    OMPI_CC = "clang";
    OMPI_CXX = "clang++";
    OMPI_FC = "flang";
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

    exec "$@"
  '';
  runEnv = version: buildFHSEnv
  {
    name = "vasp-amd-${builtins.replaceStrings ["."] [""] version}-env";
    targetPkgs = _: [ zlib (vasp version) aocc aocl openmpi gcc.cc.lib hdf5 wannier90 libpsm2 ];
    runScript = startScript version;
  };
in builtins.mapAttrs (version: _: runEnv version) sources
