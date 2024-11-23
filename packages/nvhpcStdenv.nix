{ src, stdenv, gcc, glibc_multi, autoPatchelfHook, libz, wrapCCWith, config, gfortran, overrideCC, zstd, libxml2, symlinkJoin, flock, glibc, binutils, writeText, addAttrsToDerivation, iconv, rdma-core, numactl, ncurses, dpkg }:
let
  gcc-combined = symlinkJoin
  {
    name = "gcc-combined";
    paths =
    [
      gcc gfortran glibc_multi gcc.cc.lib
      # wrapped binaries
      # stdenv.cc gfortran glibc glibc.dev binutils iconv
      # not wrapped binaries
      # gcc.cc gfortran.cc gfortran.cc.lib
    ];
  };
  nvhpc = stdenv.mkDerivation
  {
    pname = "nvhpc";
    inherit (src) src version;
    buildInputs = [ glibc_multi gcc.cc.lib libz libxml2 zstd numactl ncurses ];
    nativeBuildInputs = [ autoPatchelfHook dpkg flock ];
    langFortran = true;
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    dontShrink = true;
    unpackPhase =
    ''
      dpkg-deb -x $src .
    '';
    installPhase =
    ''
      # install component
      # NVHPC use very complex mechanism to identify the location of compilers, headers, etc.
      # we should keep the original structure
      mkdir -p $out/opt/nvidia/hpc_sdk/Linux_x86_64/${src.version}/
      cp -r opt/nvidia/hpc_sdk/Linux_x86_64/${src.version}/compilers $out/opt/nvidia/hpc_sdk/Linux_x86_64/${src.version}
    '';
    postFixup =
    ''
      sed -i '/makelocalrc executed by/d' $out/opt/nvidia/hpc_sdk/Linux_x86_64/${src.version}/compilers/bin/makelocalrc
      $out/opt/nvidia/hpc_sdk/Linux_x86_64/${src.version}/compilers/bin/makelocalrc $out/opt/nvidia/hpc_sdk/Linux_x86_64/${src.version}/compilers/bin -x -no-cuda
      ln -s $out/opt/nvidia/hpc_sdk/Linux_x86_64/${src.version}/compilers/bin $out
    '';
  };
  # fix /usr/lib/crt1.o impure path used in link
  customLocalrc = writeText "localrc"
  ''
    set DEFLIBDIR=${glibc_multi}/lib;
    set DEFSTDOBJDIR=${glibc_multi}/lib;
  '';
  cudaCapability = builtins.concatStringsSep ","
    (builtins.map (cap: "cc${builtins.replaceStrings ["."] [""] cap}") config.cudaCapabilities);
  wrapper = (wrapCCWith
  {
    cc = nvhpc;
    extraBuildCommands =
    ''
      # echo "-isystem ${nvhpc}/include" >> $out/nix-support/cc-cflags
      # echo "-L${stdenv.cc.cc}/lib/gcc/${stdenv.targetPlatform.config}/${stdenv.cc.version}" >> 
      # $out/nix-support/cc-ldflags
      echo "-L${gcc.cc.lib}/lib" >> $out/nix-support/cc-ldflags
      # echo "-L${nvhpc}/lib -L${gcc-combined}/lib --verbose" >> $out/nix-support/cc-ldflags

      echo "-tp=${config.nvhpcArch}" >> $out/nix-support/cc-cflags-before
      echo "-gpu=${cudaCapability}" >> $out/nix-support/cc-cflags-before

      # Need the gcc in the path
      # echo 'export "PATH=${gcc-combined}/bin:$PATH"' >> $out/nix-support/cc-wrapper-hook
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
in addAttrsToDerivation { NVLOCALRC = customLocalrc; } (overrideCC stdenv wrapper)
#  NIX_DEBUG = "7";
# in nvhpc
