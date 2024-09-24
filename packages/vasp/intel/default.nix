{
  stdenv, src, writeShellScriptBin, lib,
  rsync, which, wannier90, hdf5, vtst, mpi, mkl
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

    # tell openmpi use ifx
    OMPI_F90 = "ifx";
  };
in writeShellScriptBin "vasp-intel"
''
  export PATH=${vasp}/bin:${mpi}/bin''${PATH:+:$PATH}
  exec "$@"
''
