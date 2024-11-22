{ src, stdenv, gcc, glibc_multi, autoPatchelfHook, libz, wrapCCWith, config, gfortran, overrideCC, zstd, libxml2, symlinkJoin, flock, glibc, binutils, writeText, addAttrsToDerivation, iconv, rdma-core }:
let
  gccFull = symlinkJoin
  {
    name = "gcc";
    paths =
    [
      gcc gfortran glibc_multi gcc.cc.lib
      # wrapped binaries
      # stdenv.cc gfortran glibc glibc.dev binutils iconv
      # not wrapped binaries
      # stdenv.cc.cc stdenv.cc.cc.lib gfortran.cc binutils.bintools 
    ];
  };
  unwrapped = stdenv.mkDerivation
  {
    pname = "nvhpc-unwrapped";
    inherit (src) src version;
    langFortran = true;
    buildInputs = [ gccFull libz libxml2 zstd rdma-core ];
    nativeBuildInputs = [ autoPatchelfHook flock ];
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    installPhase =
    ''
      export NVHPC_SILENT=true
      export NVHPC_INSTALL_TYPE=single
      export NVHPC_INSTALL_DIR=$out/share/nvhpc
      patchShebangs install_components ./install
      sed -i '/makelocalrc executed by/d' install_components/Linux_x86_64/${src.version}/compilers/bin/makelocalrc
      ./install
      
      # remove files we did not need
      rm -rf $out/share/nvhpc/Linux_x86_64/${src.version}/{comm_libs}
    '';
  };
  customLocalrc = writeText "localrc"
  ''
    set LLVMDIR=${unwrapped}/share/llvm;
    set CPPCOMPDIR=${unwrapped}/share/tools;
    set CCOMPDIR=${unwrapped}/share/tools;
    set DEFLIBDIR=${gccFull}/lib;
    set DEFSTDOBJDIR=${gccFull}/lib;
    set PGILD="-T${unwrapped}/lib/nvhpc.ld";
    prepend PATH ${unwrapped}/lib/tools;
  '';
  cudaCapability = builtins.concatStringsSep ","
    (builtins.map (cap: "cc${builtins.replaceStrings ["."] [""] cap}") config.cudaCapabilities);
  nvhpc = (wrapCCWith
  {
    cc = unwrapped;
    extraBuildCommands =
    ''
      echo "-isystem ${unwrapped}/include" >> $out/nix-support/cc-cflags
      # echo "-L${stdenv.cc.cc}/lib/gcc/${stdenv.targetPlatform.config}/${stdenv.cc.version}" >> $out/nix-support/cc-ldflags
      # echo "-L${stdenv.cc.cc.lib}/lib" >> $out/nix-support/cc-ldflags
      # echo "-L${unwrapped}/lib" >> $out/nix-support/cc-ldflags

      echo "-tp=${config.nvhpcArch}" >> $out/nix-support/cc-cflags-before
      echo "-gpu=${cudaCapability} -#" >> $out/nix-support/cc-cflags-before

      # Need the gcc in the path
      # echo 'export "PATH=${gccFull}/bin:$PATH"' >> $out/nix-support/cc-wrapper-hook
      echo "-# -noswitcherror" >> $out/nix-support/cc-cflags

      # Disable hardening by default
      echo "" > $out/nix-support/add-hardening.sh

      for i in nvc nvc++ nvcc nvfortran; do
        wrap $i $wrapper $ccPath/$i
      done
    '';
  }).overrideAttrs (prev: { installPhase = prev.installPhase + ''
          export named_cc=nvc
      export named_cxx=nvc++
      export named_fc=nvfortran''; });
in addAttrsToDerivation { NVLOCALRC = customLocalrc; } (overrideCC stdenv nvhpc)
