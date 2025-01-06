{
  src, stdenv, autoPatchelfHook, wrapCCWith, writeText, addAttrsToDerivation, config, overrideCC, symlinkJoin,
  gcc, glibc, libz, zstd, libxml2, flock, numactl, ncurses, dpkg, cudaPackages, openssl, gmp, openssl_1_1,
  libxcrypt-legacy, libfabric, rdma-core, gfortran, xorg, makeSetupHook, writeScript, bash, overrideInStdenv
}:
let
  nvhpc = stdenv.mkDerivation
  {
    pname = "nvhpc";
    inherit (src) src version;
    buildInputs =
    [
      libz libxml2 zstd numactl ncurses openssl gmp openssl_1_1 libxcrypt-legacy libfabric rdma-core xorg.libpciaccess
    ];
    nativeBuildInputs = [ autoPatchelfHook dpkg flock ];
    langFortran = true;
    dontConfigure = true;
    dontBuild = true;
    installPhase =
    ''
      mkdir -p $out

      sed -i 's|/bin/chmod|chmod|g' install_components/install
      sed -i 's|/sbin/ldconfig|ldconfig|g' install_components/install
      patchShebangs install_components/Linux_x86_64/${src.version}/compilers/bin/makelocalrc
      sed -i '/makelocalrc executed by/d' install_components/Linux_x86_64/${src.version}/compilers/bin/makelocalrc

      NVHPC_SILENT=true NVHPC_INSTALL_DIR=$out NVHPC_INSTALL_TYPE=single ./install_components/install

      addAutoPatchelfSearchPath $out/Linux_x86_64/${src.version}/cuda/${src.cudaVersion}/targets/x86_64-linux/lib/stubs
      addAutoPatchelfSearchPath $out/Linux_x86_64/${src.version}/compilers/lib

      rm -rf $out/Linux_x86_64/${src.version}/cuda/${src.cudaVersion}/bin/cuda-gdb-python*-tui
      rm -rf $out/Linux_x86_64/${src.version}/profilers
      rm -rf $out/Linux_x86_64/${src.version}/comm_libs/${src.cudaVersion}/hpcx/hpcx-*/ompi/tests
    '';
    autoPatchelfIgnoreMissingDeps = [ "libgdrapi.so.2" "libxpmem.so.0" "libnvidia-ml.so.1" ];
  };
  # fix /usr/lib/crt1.o impure path used in link
  customLocalrc = writeText "localrc"
  ''
    set DEFLIBDIR=${glibc}/lib;
    set DEFSTDOBJDIR=${glibc}/lib;
  '';
  # do not set -gpu=cuda12.4 since this only switch the cuda version installed with NVHPC
  cudaCapability = builtins.concatStringsSep ","
  (
    (builtins.map (cap: "cc${builtins.replaceStrings ["."] [""] cap}") config.cudaCapabilities)
      ++ [ "cuda${src.cudaVersion}" ]
  );
  env = makeSetupHook { name = "nvhpc-env"; } (writeScript "nvhpc-env"
  ''
    addNvhpcEnv() {
      addToSearchPath PATH ${nvhpc}/Linux_x86_64/${src.version}/compilers/bin
      addToSearchPath PATH ${nvhpc}/Linux_x86_64/${src.version}/comm_libs/mpi/bin
      addToSearchPath PATH ${gcc.cc}/bin
      export NVLOCALRC=${customLocalrc}
    }
    addEnvHooks "$hostOffset" addNvhpcEnv
  '');
  wrapper = (wrapCCWith
  {
    cc = nvhpc;
    extraBuildCommands =
    ''
      # make -lgomp find libgomp.so provided by nvhpc instead of gcc
      echo "-L${nvhpc}/Linux_x86_64/${src.version}/compilers/lib" >> $out/nix-support/cc-ldflags

      # provide libgcc_s.so but not libgomp.so
      echo "-L${gcc.cc.libgcc}/lib" >> $out/nix-support/cc-ldflags

      echo "-tp=${config.nvhpcArch}" >> $out/nix-support/cc-cflags-before
      echo "-gpu=${cudaCapability}" >> $out/nix-support/cc-cflags-before

      echo "-noswitcherror" >> $out/nix-support/cc-cflags

      # print verbose output for debugging
      # echo "-v" >> $out/nix-support/cc-cflags

      # echo "" > $out/nix-support/add-hardening.sh

      # substitute -idirafter in libc-cflags
      # somehow -isystem does not work
      sed -i 's/-idirafter/-I/g' $out/nix-support/libc-cflags

      for i in nvc nvc++ nvcc nvfortran; do
        wrap $i $wrapper ${nvhpc}/Linux_x86_64/${nvhpc.version}/compilers/bin/$i
      done
    '';
  }).overrideAttrs (prev: { installPhase = prev.installPhase +
  ''
    export named_cc=nvc
    export named_cxx=nvc++
    export named_fc=nvfortran
  '';});
in overrideInStdenv (overrideCC stdenv wrapper) [ env ]
