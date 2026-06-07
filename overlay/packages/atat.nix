{
  stdenv,
  src,
  perl,
  coreutils,
}:
stdenv.mkDerivation {
  name = "atat";
  inherit src;
  nativeBuildInputs = [ perl ];
  configurePhase = ''
    patchShebangs src
    echo "#!/bin/sh" > safecp
    echo "cp \"\$@\"" >> safecp
  '';
  buildPhase = "make -C src -j$NIX_BUILD_CORES";
  installPhase = ''
    mkdir -p $out/bin
    make -C src BINDIR=$out/bin install
  '';
}
