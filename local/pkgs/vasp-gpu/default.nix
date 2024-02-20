{
  stdenvNoCC, requireFile,
  nvhpc, rsync, mkl, lmod, bash, which,
  glibc_multi
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
  makeFlags = "DEPS=1";
  enableParallelBuilding = true;
  buildInputs = [ nvhpc mkl glibc_multi ];
  nativeBuildInputs = [ rsync bash which ];
  MKLROOT = mkl;
  configurePhase =
  ''
    cp ${./makefile.include} makefile.include
    . ${lmod}/lmod/lmod/init/bash
    module use ${nvhpc}/share/nvhpc/modulefiles
    module load nvhpc
    # chmod +w makefile.include
    # echo "CPP_OPTIONS += -Duse_shmem -Dshmem_bcast_buffer -Dshmem_rproj" >> makefile.include
    # echo "OBJECTS_LIB += getshmem.o" >> makefile.include
    mkdir -p bin
  '';
  installPhase =
  ''
    mkdir -p $out
    cp -r bin $out
  '';
}
