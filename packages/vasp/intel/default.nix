{
  stdenv, src, writeShellScriptBin, lib,
  rsync, which, wannier90, hdf5, vtst, mpi, mkl
}:
let vasp = stdenv.mkDerivation
  {
    name = "vasp-intel";
    inherit src;
    patches = [ ../vtst.patch ];
    configurePhase =
    ''
      cp ${./makefile.include} makefile.include
      chmod +w makefile.include
      cp ${../constr_cell_relax.F} src/constr_cell_relax.F
      cp -r ${vtst}/vtstcode6.4.3/* src
      chmod -R +w src
    '';
    buildInputs = [ hdf5 wannier90 mkl ];
    nativeBuildInputs = [ rsync which mpi ];
    installPhase =
    ''
      mkdir -p $out/bin
      for i in std gam ncl; do cp bin/vasp_$i $out/bin/vasp-$i; done
      mkdir $out/src
      ln -s ${src} $out/src/vasp
      ln -s ${vtst} $out/src/vtst
    '';

    # NIX_DEBUG = "7";

    # enable parallel build
    enableParallelBuilding = true;
    DEPS = "1";

    # vasp directly include headers under ${mkl}/include/fftw
    MKLROOT = mkl;

    # tell openmpi use ifx
    OMPI_F90 = "ifx";
  };
in writeShellScriptBin "vasp-intel"
''
  export PATH=${vasp}/bin:${mpi}/bin''${PATH:+:$PATH}

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

  exec "$@"
''
