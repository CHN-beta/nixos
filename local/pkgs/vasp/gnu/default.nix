{
  stdenvNoCC, requireFile, writeShellApplication, substituteAll,
  rsync, blas, scalapack, mpi, openmp, gfortran, gcc, fftwMpi, hdf5, wannier90,
  additionalCommands ? ""
}:
let
  sources = import ../source.nix { inherit requireFile; };
  include = version: ./makefile.include-${version};
  vasp = version: stdenvNoCC.mkDerivation rec
  {
    pname = "vasp-gnu";
    inherit version;
    src = sources.${version};
    configurePhase =
    ''
      cp ${include version} makefile.include
      cp ${../constr_cell_relax.F} src/constr_cell_relax.F
      mkdir -p bin
    '';
    enableParallelBuilding = true;
    makeFlags = "DEPS=1";
    buildInputs = [ blas scalapack mpi openmp fftwMpi.dev fftwMpi hdf5 hdf5.dev wannier90 ];
    nativeBuildInputs = [ rsync gfortran gfortran.cc gcc ];
    FFTW_ROOT = fftwMpi.dev;
    HDF5_ROOT = hdf5.dev;
    WANNIER90_ROOT = wannier90;
    installPhase =
    ''
      mkdir -p $out/bin
      for i in std gam ncl; do
        cp bin/vasp_$i $out/bin/vasp-$i
      done
    '';
  };
  startScript = version: writeShellApplication
  {
    name = "vasp-gnu-${version}";
    runtimeInputs = [ (vasp version) ];
    text =
    ''
      # if SLURM_CPUS_PER_TASK is set, use it to set OMP_NUM_THREADS
      if [ -n "''${SLURM_CPUS_PER_TASK-}" ]; then
        export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
      fi

      ${additionalCommands}

      exec "$@"
    '';
  };
in builtins.mapAttrs (version: _: startScript version) sources
