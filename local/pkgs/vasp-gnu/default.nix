{
  stdenvNoCC, requireFile,
  rsync, blas, scalapack, mpi, openmp, gfortran, gcc, fftwMpi
}:
let
  versions =
  {
    "6.3.1" = "1xdr5kjxz6v2li73cbx1ls5b1lnm6z16jaa4fpln7d3arnnr1mgx";
    "6.4.0" = "189i1l5q33ynmps93p2mwqf5fx7p4l50sls1krqlv8ls14s3m71f";
  };
  vasp = version: stdenvNoCC.mkDerivation rec
  {
    pname = "vasp-gnu";
    inherit version;
    src = requireFile
    {
      name = "vasp-${version}";
      sha256 = versions.${version};
      hashMode = "recursive";
      message = "Source file not found.";
    };
    configurePhase =
    ''
      cp ${./makefile.include-${version}} makefile.include
      cp ${../vasp-gpu/constr_cell_relax.F} src/constr_cell_relax.F
      mkdir -p bin
    '';
    enableParallelBuilding = true;
    makeFlags = "DEPS=1";
    buildInputs = [ blas scalapack mpi openmp fftwMpi.dev fftwMpi ];
    nativeBuildInputs = [ rsync gfortran gfortran.cc gcc ];
    FFTW_ROOT = fftwMpi.dev;
    installPhase =
    ''
      mkdir -p $out/bin
      for i in std gam ncl; do
        cp bin/vasp_$i $out/bin/vasp-${version}-$i
      done
    '';
  };
in builtins.mapAttrs (version: _: vasp version) versions
