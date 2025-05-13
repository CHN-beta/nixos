{
  src, stdenv, autoPatchelfHook, wrapCCWith, config, overrideCC, makeSetupHook, writeScript, overrideInStdenv,
  runCommand,
  gcc, glibc, libz, zstd, libxml2, flock, numactl, ncurses, openssl, gmp, kdePackages,
  libxcrypt-legacy, libfabric, rdma-core, xorg, bash
}:
let
  oneapi = stdenv.mkDerivation
  {
    pname = "oneapi";
    inherit (src) src version;
    buildInputs = [];
    nativeBuildInputs = [ ncurses stdenv.cc.cc autoPatchelfHook ];
    langFortran = true;
    dontConfigure = true;
    dontBuild = true;
    unpackPhase =
    ''
      mkdir installer
      sh ${src.src} --extract-only --extract-folder installer
      addAutoPatchelfSearchPath installer/intel*/lib
      autoPatchelf installer/intel*/bootstrapper
    '';
    installPhase =
    ''
      mkdir -p $out/install
      export HOME=$out
      echo "will install to $out/install"
      sh installer/intel*/install.sh --silent --eula accept --install-dir $out/install
      mv $out/install/compiler/${src.version}/{bin,include,lib,share,opt/compiler/include} $out
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
