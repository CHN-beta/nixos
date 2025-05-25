{
  src, stdenv, autoPatchelfHook, wrapCCWith, config, overrideCC, makeSetupHook, writeScript, overrideInStdenv,
  runCommand,
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
    '';
    autoPatchelfIgnoreMissingDeps = [ "libze_loader.so.1" "libcuda.so.1" "libhwloc.so.5" ];
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
