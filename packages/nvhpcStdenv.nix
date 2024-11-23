{ src, stdenv, gcc, glibc_multi, autoPatchelfHook, libz, wrapCCWith, config, gfortran, overrideCC, zstd, libxml2, symlinkJoin, flock, glibc, binutils, writeText, addAttrsToDerivation, iconv, rdma-core, numactl, ncurses }:
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
  unwrapped = stdenv.mkDerivation
  {
    pname = "nvhpc-unwrapped";
    inherit (src) src version;
    langFortran = true;
    buildInputs = [ gcc-combined libz libxml2 zstd numactl ncurses ];
    nativeBuildInputs = [ autoPatchelfHook flock ];
    dontConfigure = true;
    dontBuild = true;
    dontStrip = true;
    installPhase =
    ''
      # install component
      # NVHPC use very complex mechanism to identify the location of compilers, headers, etc.
      # we should keep the original structure
      mkdir -p $out/opt/nvhpc/Linux_x86_64/${src.version}
      cp -r install_components/Linux_x86_64/${src.version}/compilers $out/opt/nvhpc/Linux_x86_64/${src.version}
      ln -s $out/opt/nvhpc/Linux_x86_64/${src.version}/compilers/bin $out

      # create localrc
      patchShebangs $out/opt/nvhpc/Linux_x86_64/${src.version}/compilers/bin/makelocalrc
      sed -i '/makelocalrc executed by/d' $out/opt/nvhpc/Linux_x86_64/${src.version}/compilers/bin/makelocalrc
      $out/opt/nvhpc/Linux_x86_64/${src.version}/compilers/bin/makelocalrc -x
    '';
  };
  # fix /usr/lib/crt1.o impure path used in link
  customLocalrc = writeText "localrc"
  ''
    set DEFLIBDIR=${gcc-combined}/lib;
    set DEFSTDOBJDIR=${gcc-combined}/lib;
  '';
  cudaCapability = builtins.concatStringsSep ","
    (builtins.map (cap: "cc${builtins.replaceStrings ["."] [""] cap}") config.cudaCapabilities);
  nvhpc = (wrapCCWith
  {
    cc = unwrapped;
    extraBuildCommands =
    ''
      # echo "-isystem ${unwrapped}/include" >> $out/nix-support/cc-cflags
      # echo "-L${stdenv.cc.cc}/lib/gcc/${stdenv.targetPlatform.config}/${stdenv.cc.version}" >> $out/nix-support/cc-ldflags
      # echo "-L${stdenv.cc.cc.lib}/lib" >> $out/nix-support/cc-ldflags
      # echo "-L${unwrapped}/lib -L${gcc-combined}/lib --verbose" >> $out/nix-support/cc-ldflags

      echo "-tp=${config.nvhpcArch}" >> $out/nix-support/cc-cflags-before
      echo "-gpu=${cudaCapability} -#" >> $out/nix-support/cc-cflags-before

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
in addAttrsToDerivation { NVLOCALRC = customLocalrc; } (overrideCC stdenv nvhpc)
#  NIX_DEBUG = "7";
