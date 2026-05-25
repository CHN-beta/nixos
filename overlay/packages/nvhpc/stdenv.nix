{
  src, stdenv, autoPatchelfHook, wrapCCWith, config, overrideCC, makeSetupHook, writeScript, overrideInStdenv,
  gcc, glibc, libz, zstd, libxml2_13, flock, numactl, ncurses, openssl, gmp,
  libxcrypt-legacy, libfabric, rdma-core, bash, libpciaccess
}:
let
  nvhpc = stdenv.mkDerivation
  {
    pname = "nvhpc";
    inherit (src) src version;
    buildInputs =
      [ libz libxml2_13 zstd numactl ncurses openssl gmp libxcrypt-legacy libfabric rdma-core libpciaccess ];
    nativeBuildInputs = [ autoPatchelfHook flock ];
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
      rm $out/Linux_x86_64/${src.version}/compilers/bin/{ncu,nsys}-ui

      # fix /usr/lib/crt1.o impure path used in link
      cat >> $out/Linux_x86_64/${src.version}/compilers/bin/localrc << EOF

      set DEFLIBDIR=${glibc}/lib;
      set DEFSTDOBJDIR=${glibc}/lib;
      EOF
    '';
    autoPatchelfIgnoreMissingDeps = [ "libcrypto.so.1.1" "libgdrapi.so.2" "libxpmem.so.0" "libnvidia-ml.so.1" ];
    passthru = { inherit src cudaCapability buildEnv runEnv; };
  };
  compilerDir = "${nvhpc}/Linux_x86_64/${src.version}/compilers";
  cudaCapability = builtins.concatStringsSep ","
  (
    (builtins.map (cap: "cc${builtins.replaceStrings ["."] [""] cap}") config.cudaCapabilities)
      ++ [ "cuda${src.cudaVersion}" ]
  );
  buildEnv = makeSetupHook { name = "nvhpcBuildEnv"; } (writeScript "nvhpcBuildEnv"
  ''
    addNvhpcEnv() {
      addToSearchPath PATH ${compilerDir}/bin
      addToSearchPath PATH ${gcc.cc}/bin
    }
    addEnvHooks "$hostOffset" addNvhpcEnv
  '');
  runEnv = writeScript "nvhpcRunEnv"
  ''
    #!${bash}/bin/bash
    # make mpirun and nvaccelinfo accessible
    export PATH=${compilerDir}/bin''${PATH:+:$PATH}
    # NVPL need this to load libgomp.so (actually libnvomp.so) from nvhpc instead of from gcc
    # https://docs.nvidia.com/nvpl/
    export LD_LIBRARY_PATH=${compilerDir}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
    # allow access to libcuda.so
    export LD_LIBRARY_PATH=/run/opengl-driver/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}
    # set NCCL_SOCKET_IFNAME to lo if not set
    if [ -z "$NCCL_SOCKET_IFNAME" ]; then
      export NCCL_SOCKET_IFNAME==lo
    fi
    exec "$@"
  '';
  wrapper = (wrapCCWith
  {
    cc = nvhpc;
    extraBuildCommands =
    ''
      echo "-L${gcc.cc.libgcc.lib}/lib" >> $out/nix-support/cc-ldflags

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
in overrideInStdenv (overrideCC stdenv wrapper) [ buildEnv ]
