{
  src, stdenv, autoPatchelfHook, wrapCCWith, config, overrideCC, makeSetupHook, writeScript, overrideInStdenv,
  runCommand, lib, gccFull,
  gcc, glibc, zlib, zstd, libxml2, flock, numactl, ncurses, openssl, gmp, kdePackages,
  libxcrypt-legacy, libfabric, rdma-core, xorg, bash, p7zip, hwloc
}:
let
  oneapi = stdenv.mkDerivation
  {
    pname = "oneapi";
    inherit (src) src version;
    buildInputs = [ zlib stdenv.cc.cc hwloc ];
    nativeBuildInputs = [ autoPatchelfHook p7zip ];
    langFortran = true;
    dontUnpack = true;
    dontConfigure = true;
    dontBuild = true;
    installPhase =
      let installComponents = builtins.concatStringsSep "\n" (builtins.map
        (component:
        ''
          pushd ${component}
            7za x cupPayload.cup
            cp -r _installdir/* ../../../../install
          popd
        '')
        src.components);
      in
    ''
      mkdir -p installer install $out
      sh ${src.src} --extract-only --extract-folder installer
      pushd installer/intel-oneapi-hpc-toolkit-${src.fullVersion}_offline/packages
        ${installComponents}
      popd
      cp -r install/compiler/${src.version}/{bin,include,lib,share} $out
      cp -r install/{mpi,tbb,umf}/*/lib $out

      # mv $out/bin/compiler/* $out/bin
      # rm -r $out/bin/compiler
      # mv $out/bin/clang%2B%2B $out/bin/clang++
      mv $out/bin/compiler/clang%2B%2B $out/bin/compiler/clang++

      # mv $out/lib/crt/* $out/lib
      # rm -r $out/lib/crt
    '';
    autoPatchelfIgnoreMissingDeps = [ "libze_loader.so.1" "libcuda.so.1" "libhwloc.so.5" ];
    passthru = { inherit src; };
  };
  wrapper = (wrapCCWith
  {
    cc = oneapi;
    extraBuildCommands =
      let
        gcc = stdenv.cc.cc;
        gccVersion = builtins.concatStringsSep "." (lib.take 3 (builtins.splitVersion gcc.version));
      in
      ''
        echo "-isystem ${oneapi}/include" >> $out/nix-support/cc-cflags
        echo "-isystem ${oneapi}/include/intel64" >> $out/nix-support/cc-cflags
        echo "-isystem ${oneapi}/include/icx" >> $out/nix-support/cc-cflags
        echo "-isystem ${gcc}/include/c++/${gcc.version}/${stdenv.targetPlatform.config}" >> $out/nix-support/cc-cflags
        echo "-isystem ${gcc}/include/c++/${gcc.version}" >> $out/nix-support/cc-cflags
        echo "--gcc-toolchain=${stdenv.cc}/lib/gcc/x86_64-unknown-linux-gnu/14.2.1" >> $out/nix-support/cc-cflags
        echo "-march=${config.oneapiArch}" >> $out/nix-support/cc-cflags-before

        echo "-L${gcc.lib}/lib" >> $out/nix-support/cc-ldflags
        echo "-L${gcc}/lib/gcc/${stdenv.targetPlatform.config}/${gccVersion}" >> $out/nix-support/cc-ldflags
        echo "-L${oneapi}/lib" >> $out/nix-support/cc-ldflags
        echo "-Lsome_path_does_not_exist" >> $out/nix-support/cc-ldflags

        # echo 'export "PATH=${gcc}/bin:$PATH"' >> $out/nix-support/cc-wrapper-hook

        echo "" > $out/nix-support/add-hardening.sh

        echo "-v" >> $out/nix-support/cc-cflags

        for i in icx icpx ifx; do
          wrap $i $wrapper ${oneapi}/bin/$i
        done
      '';
  }).overrideAttrs (prev: { installPhase = prev.installPhase +
  ''
    export named_cc=icx
    export named_cxx=icpx
    export named_fc=ifx
  '';});
in overrideInStdenv (overrideCC stdenv wrapper) [ ]
