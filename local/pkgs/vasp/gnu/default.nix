{
  stdenvNoCC, requireFile,
  rsync, blas, scalapack, mpi, openmp, gfortran, gcc, fftwMpi, hdf5, wannier90
}:
let
  versions = import ../source.nix;
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
        cp bin/vasp_$i $out/bin/vasp-gnu-${version}-$i
      done
    '';
  };
in builtins.mapAttrs (version: _: vasp version) versions
