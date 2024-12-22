{
  src, stdenv, autoPatchelfHook, wrapCCWith, writeText, addAttrsToDerivation, config, overrideCC, symlinkJoin,
  gcc, glibc_multi, libz, zstd, libxml2, flock, numactl, ncurses, dpkg, cudaPackages, openssl, gmp, openssl_1_1,
  libxcrypt-legacy, libfabric, rdma-core
}:
let
  nvhpc = stdenv.mkDerivation
  {
    pname = "nvhpc";
    inherit (src) src version;
    buildInputs = [ libz libxml2 zstd numactl ncurses openssl gmp openssl_1_1 libxcrypt-legacy libfabric rdma-core ];
    nativeBuildInputs = [ autoPatchelfHook dpkg flock ];
    langFortran = true;
    dontConfigure = true;
    dontBuild = true;
    unpackPhase = ''dpkg-deb -x $src .'';
    installPhase =
    ''
      # install component
      # NVHPC use very complex mechanism to identify the location of compilers, headers, etc.
      # we should keep the original structure
      mkdir -p $out
      cp -r opt $out
      rm -rf $out/opt/nvidia/hpc_sdk/Linux_x86_64/${src.version}/{examples,profilers,comm_libs/${src.cudaVersion}/hpcx/hpcx-*/ompi/tests,cuda/12.6/bin/cuda-gdb-python3.10-tui}

      mkdir -p $out/nix-support
      > $out/nix-support/setup-hook << EOF
      addNvhpcEnv() {
        addToSearchPath PATH $out/opt/nvidia/hpc_sdk/Linux_x86_64/${src.version}/compilers/bin
        addToSearchPath PATH $out/opt/nvidia/hpc_sdk/Linux_x86_64/${src.version}/comm_libs/mpi/bin
      }
      addEnvHooks "$hostOffset" addHarepath
      EOF
    '';
    autoPatchelfIgnoreMissingDeps = [ "libgdrapi.so.2" ];
    postFixup =
    ''
      sed -i '/makelocalrc executed by/d' $out/opt/nvidia/hpc_sdk/Linux_x86_64/${src.version}/compilers/bin/makelocalrc
      $out/opt/nvidia/hpc_sdk/Linux_x86_64/${src.version}/compilers/bin/makelocalrc \
        $out/opt/nvidia/hpc_sdk/Linux_x86_64/${src.version}/compilers/bin -x
    '';
  };
  # fix /usr/lib/crt1.o impure path used in link
  customLocalrc = writeText "localrc"
  ''
    set DEFLIBDIR=${glibc_multi}/lib;
    set DEFSTDOBJDIR=${glibc_multi}/lib;
  '';
  # do not set -gpu=cuda12.4 since this only switch the cuda version installed with NVHPC
  cudaCapability = builtins.concatStringsSep ","
  (
    (builtins.map (cap: "cc${builtins.replaceStrings ["."] [""] cap}") config.cudaCapabilities)
      ++ [ "cuda12.6" ]
  );
  wrapper = (wrapCCWith
  {
    cc = nvhpc;
    extraBuildCommands =
    ''
      echo "-L${gcc}/lib" >> $out/nix-support/cc-ldflags

      echo "-tp=${config.nvhpcArch}" >> $out/nix-support/cc-cflags-before
      echo "-gpu=${cudaCapability}" >> $out/nix-support/cc-cflags-before

      echo "-noswitcherror" >> $out/nix-support/cc-cflags

      echo 'export "PATH=${gcc}/bin:$PATH"' >> $out/nix-support/cc-wrapper-hook

      # print verbose output for debugging
      echo "-v" >> $out/nix-support/cc-cflags
      # echo "-#" >> $out/nix-support/cc-cflags

      # echo "" > $out/nix-support/add-hardening.sh

      # substitute -idirafter in libc-cflags
      # somehow -isystem does not work
      sed -i 's/-idirafter/-I/g' $out/nix-support/libc-cflags

      for i in nvc nvc++ nvcc nvfortran; do
        wrap $i $wrapper $ccPath/$i
      done
    '';
  }).overrideAttrs (prev: { installPhase = prev.installPhase +
  ''
    export named_cc=nvc
    export named_cxx=nvc++
    export named_fc=nvfortran
  '';});
in addAttrsToDerivation { NVLOCALRC = customLocalrc; } (overrideCC stdenv wrapper)
