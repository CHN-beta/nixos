{
  stdenvNoCC, writeShellApplication, src,
  rsync, blas, scalapack, mpi, openmp, gfortran, gcc, fftwMpi, hdf5, wannier90
}:
let vasp = stdenvNoCC.mkDerivation
{
  name = "vasp-gnu";
  inherit src;
  configurePhase =
  ''
    cp ${./makefile.include} makefile.include
    cp ${../constr_cell_relax.F} src/constr_cell_relax.F
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
    ln -s ${src} $out/src
  '';
};
in writeShellApplication
{
  name = "vasp-gnu-env";
  runtimeInputs = [ vasp ];
  text =
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

    exec "$@"
  '';
}
