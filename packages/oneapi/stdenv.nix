{
  src, stdenv, autoPatchelfHook, wrapCCWith, config, overrideCC, makeSetupHook, writeScript, overrideInStdenv,
  gcc, glibc, libz, zstd, libxml2, flock, numactl, ncurses, openssl, gmp,
  libxcrypt-legacy, libfabric, rdma-core, xorg, bash
}:
let
  oneapi = stdenv.mkDerivation
  {
    pname = "oneapi";
    inherit src;
    buildInputs = [];
    nativeBuildInputs = [ autoPatchelfHook ];
    langFortran = true;
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    installPhase =
    ''
      sh $src -a --silent --eula accept --install-dir $out/install
      mv $out/install/compiler/2025.1/{bin,include,lib,share,opt/compiler/include} $out
      mv $out/bin/compiler/* $out/bin
      rm -rf $out/install
      # addAutoPatchelfSearchPath
    '';
    autoPatchelfIgnoreMissingDeps = [];
    passthru = { inherit src; };
  };
  wrapper = (wrapCCWith
  {
    cc = oneapi;
    extraBuildCommands =
    ''
      # provide libgcc_s.so but not libgomp.so
      echo "-L${gcc.cc.libgcc}/lib" >> $out/nix-support/cc-ldflags

      echo "-tp=${config.nvhpcArch}" >> $out/nix-support/cc-cflags-before

      echo "-noswitcherror" >> $out/nix-support/cc-cflags

      # print verbose output for debugging
      # echo "-v" >> $out/nix-support/cc-cflags

      # echo "" > $out/nix-support/add-hardening.sh

      # substitute -idirafter in libc-cflags
      # somehow -isystem does not work
      sed -i 's/-idirafter/-I/g' $out/nix-support/libc-cflags

      for i in nvc nvc++ nvcc nvfortran; do
        wrap $i $wrapper ${oneapi}/bin/$i
      done
    '';
  }).overrideAttrs (prev: { installPhase = prev.installPhase +
  ''
    export named_cc=nvc
    export named_cxx=nvc++
    export named_fc=nvfortran
  '';});
# in overrideInStdenv (overrideCC stdenv wrapper) [ ]
in oneapi
