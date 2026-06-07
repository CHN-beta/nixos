{
  stdenv,
  src,
  writeShellScriptBin,
  lib,
  rsync,
  which,
  wannier90,
  hdf5,
  mpi,
  mkl,
  prrte,
  suffix ? "intel",
  oneapiArch ? null,
}:
let
  vasp = stdenv.mkDerivation {
    name = "vasp-${suffix}";
    src = src.vasp;
    patches = [ ../vtst.patch ];
    configurePhase = ''
      cp ${./makefile.include} makefile.include
      chmod +w makefile.include
      cp ${../constr_cell_relax.F} src/constr_cell_relax.F
      cp -r ${src.vtst.patch}/vtstcode6.4.3/* src
      chmod -R +w src
    '';
    buildInputs = [
      hdf5
      wannier90
      mkl
    ];
    nativeBuildInputs = [
      rsync
      which
      mpi
    ];
    installPhase = ''
      mkdir -p $out/bin
      for i in std gam ncl; do cp bin/vasp_$i $out/bin/vasp-$i; done
    '';
    # NIX_DEBUG = "7";
    enableParallelBuilding = true;
    env = {
      DEPS = "1";
      MKLROOT = mkl;
      OMPI_F90 = "ifx";
    }
    // (lib.optionalAttrs (oneapiArch != null) { NIX_ONEAPI_ARCH = oneapiArch; });
  };
  wrapper = writeShellScriptBin "vasp-${suffix}" ''
    export PATH=${vasp}/bin:${mpi}/bin:${mpi.dev}/bin:${prrte}/bin:${prrte.dev}/bin''${PATH:+:$PATH}

    ulimit -s unlimited

    # set OMP_NUM_THREADS if SLURM_CPUS_PER_TASK is set
    if [ -z "$OMP_NUM_THREADS" ] && [ -n "$SLURM_CPUS_PER_TASK" ]; then
      export OMP_NUM_THREADS=$SLURM_CPUS_PER_TASK
    fi
    # set OMP_NUM_THREADS to 1 if not set
    if [ -z "$OMP_NUM_THREADS" ]; then
      export OMP_NUM_THREADS=1
    fi
    # set OMP_STACKSIZE to 512M if not set
    if [ -z "$OMP_STACKSIZE" ]; then
      export OMP_STACKSIZE=512m
    fi

    # let OpenMPI propagate these environment variables on remote hosts
    export OMPI_MCA_mca_base_env_list="PATH;OMP_NUM_THREADS;OMP_STACKSIZE"

    exec "$@"
  '';
in
wrapper
// {
  passthru = wrapper.passthru // {
    inherit mpi;
  };
}
