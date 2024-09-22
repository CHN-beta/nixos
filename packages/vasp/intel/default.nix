{
  stdenv, src, writeShellScriptBin, lib,
  rsync, which, wannier90, hdf5, vtst, mpi, mkl, libfabric,
  integratedWithSlurm ? false, slurm
}:
let vasp = stdenv.mkDerivation
  {
    name = "vasp-intel";
    inherit src;
    # patches = [ ../vtst.patch ];
    configurePhase =
    ''
      cp ${./makefile.include} makefile.include
      chmod +w makefile.include
      cp ${../constr_cell_relax.F} src/constr_cell_relax.F
      # cp -r ${vtst}/* src
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
  };
in writeShellScriptBin "vasp-intel"
''
  # not sure why mpi could not find libfabric.so
  export LD_LIBRARY_PATH=${libfabric}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}

  # intel mpi need this to talk with slurm
  ${lib.optionalString integratedWithSlurm "export I_MPI_PMI_LIBRARY=${slurm}/lib/libpmi2.so"}

  # add vasp and intel mpi in PATH
  export PATH=${vasp}/bin:${mpi}/bin''${PATH:+:$PATH}

  exec "$@"
''
