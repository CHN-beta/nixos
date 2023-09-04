# {
#   stdenv, requireFile, config, rsync, intel-mpi, ifort,
#   mkl
# }:
# stdenv.mkDerivation rec
# {
#   pname = "vasp";
#   version = "6.4.0";
#   # nix-store --query --hash $(nix store add-path ./vasp-6.4.0)
#   src = requireFile
#   {
#     name = "${pname}-${version}";
#     sha256 = "189i1l5q33ynmps93p2mwqf5fx7p4l50sls1krqlv8ls14s3m71f";
#     hashMode = "recursive";
#     message = "Source file not found.";
#   };
#   VASP_TARGET_CPU = if config ? oneapiArch then "-x${config.oneapiArch}" else "";
#   MKLROOT = mkl;
#   makeFlags = "DEPS=1";
#   enableParallelBuilding = true;
#   buildInputs = [ mkl intel-mpi ifort ];
#   nativeBuildInputs = [ rsync ];
#   configurePhase =
#   ''
#     cp arch/makefile.include.intel makefile.include
#     echo "CPP_OPTIONS += -Duse_shmem -Dshmem_bcast_buffer -Dshmem_rproj" >> makefile.include
#     echo "OBJECTS_LIB += getshmem.o" >> makefile.include
#     mkdir -p bin
#   '';
#   installPhase =
#   ''
#     mkdir -p $out/bin
#     for i in std gam ncl; do
#       cp bin/vasp_$i $out/bin/vasp-cpu-${version}-$i
#     done
#   '';
#   doStrip = false;
#   doFixup = false;
# }
{
  stdenvNoCC, requireFile, rsync, blas, scalapack, openmpi, openmp, gfortran, gcc, fftwMpi
}:
stdenvNoCC.mkDerivation rec
{
  pname = "vasp";
  version = "6.4.0";
  # nix-store --query --hash $(nix store add-path ./vasp-6.4.0)
  src = requireFile
  {
    name = "${pname}-${version}";
    sha256 = "189i1l5q33ynmps93p2mwqf5fx7p4l50sls1krqlv8ls14s3m71f";
    hashMode = "recursive";
    message = "Source file not found.";
  };
  # VASP_TARGET_CPU = if config ? oneapiArch then "-x${config.oneapiArch}" else "";
  # MKLROOT = mkl;
  makeFlags = "DEPS=1";
  enableParallelBuilding = true;
  buildInputs = [ blas scalapack openmpi openmp gfortran gfortran.cc gcc fftwMpi.dev fftwMpi ];
  nativeBuildInputs = [ rsync ];
  FFTW_ROOT = fftwMpi.dev;
  configurePhase =
  ''
    cp ${./makefile.include/${version}-gnu} makefile.include
    chmod +w makefile.include
    echo "CPP_OPTIONS += -Duse_shmem -Dshmem_bcast_buffer -Dshmem_rproj" >> makefile.include
    echo "OBJECTS_LIB += getshmem.o" >> makefile.include
    mkdir -p bin
  '';
  installPhase =
  ''
    mkdir -p $out/bin
    for i in std gam ncl; do
      cp bin/vasp_$i $out/bin/vasp-gnu-${version}-$i
    done
  '';
}
