# pick from nixpkgs 24e16d8b21f698cbe372be67b645a1919bfd0d20
{
  requireFile,
  stdenv,
  lib,
  src,
  perl,
  libnl,
  rdma-core,
  zlib,
  numactl,
  libevent,
  hwloc,
  libpsm2,
  libfabric,
  pmix,
  ucx,
  ucc,
  prrte,
}:
stdenv.mkDerivation {
  name = "openmpi";
  inherit src;
  postPatch = ''
    patchShebangs ./
    ${lib.pipe
      {
        sse3 = true;
        sse41 = true;
        avx = true;
        avx2 = stdenv.hostPlatform.avx2Support;
        avx512 = stdenv.hostPlatform.avx512Support;
      }
      [
        (lib.mapAttrsToList (
          option: val: ''
            substituteInPlace configure \
              --replace-fail \
                ompi_cv_op_avx_check_${option}=yes \
                ompi_cv_op_avx_check_${option}=${if val then "yes" else "no"}
          ''
        ))
        (lib.concatStringsSep "\n")
      ]
    }
  '';
  env = {
    USER = "nixbld";
    HOSTNAME = "localhost";
    SOURCE_DATE_EPOCH = "0";
  };

  buildInputs = [
    zlib
    libevent
    hwloc
    libnl
    numactl
    pmix
    ucx
    ucc
    prrte
    rdma-core
    libpsm2
    libfabric
  ];

  nativeBuildInputs = [ perl ];

  configureFlags = [
    "--enable-mca-dso"
    "--enable-mpi-fortran"
    "--with-libnl=${lib.getDev libnl}"
    "--with-pmix=${lib.getDev pmix}"
    "--with-pmix-libdir=${lib.getLib pmix}/lib"
    "--with-prrte=${lib.getBin prrte}"
    "--enable-sge"
    "--enable-mpirun-prefix-by-default"
    "--with-cuda=${stdenv.cc.cc}/Linux_x86_64/${stdenv.cc.cc.version}/cuda/${stdenv.cc.cc.passthru.src.cudaVersion}"
    "--enable-dlopen"
    "--with-psm2=${lib.getDev libpsm2}"
    "--with-ofi=${lib.getDev libfabric}"
    "--with-ofi-libdir=${lib.getLib libfabric}/lib"
    "--with-slurm"
    "--with-libevent=${lib.getDev libevent}"
    "--with-hwloc=${lib.getDev hwloc}"
  ];

  enableParallelBuilding = true;
  doCheck = true;
}
