{ stdenvNoCC, fetchurl, cpio, rpm }:

stdenvNoCC.mkDerivation rec {
  name = "linux-3.10.0-1127.el7.tar.xz";
  version = "3.10.0-1127.el7";

  src = fetchurl {
    url = "https://vault.centos.org/7.8.2003/os/Source/SPackages/kernel-${version}.src.rpm";
    hash = "sha256-CkK+11rUTN2+vfcQBIm4+Yywr5mD/XlFFDZi/TRte+c=";
  };

  nativeBuildInputs = [ cpio rpm ];

  unpackPhase = "true";

  buildPhase = ''
    rpm2cpio $src | cpio -idmv linux-3.10.0-1127.el7.tar.xz
  '';

  installPhase = ''
    cp linux-3.10.0-1127.el7.tar.xz $out
  '';

  outputHashMode = "flat";
  outputHashAlgo = "sha256";
  outputHash = "sha256-FqAMSJLSMnSF8LrbT7omnVV9HqPL7z1CtsYh2a1CjNk=";
}
