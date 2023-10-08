{ lib, stdenv, fetchFromGitHub, python3 }:
let
  python = python3.withPackages (ps: with ps; [ evdev pyudev ]);
in stdenv.mkDerivation
{
  name = "yogabook-support";
  src = fetchFromGitHub
  {
    owner = "jekhor";
    repo = "yogabook-support";
    rev = "8ecf7861e469ba4094115fff0e81d537135e3f22";
    sha256 = "4UtiQooCaeUDHc9YE9EQRJ2MNKvOqqCv85k0YyI2BO4=";
  };
  buildInputs = [ python ];
  installPhase =
  ''
    mkdir -p $out/bin
    cp pen-key-handler yogabook-modes-handler $out/bin
    mkdir -p $out/lib/udev/rules.d
    cp 61-sensor-yogabook.rules $out/lib/udev/rules.d
    mkdir -p $out/lib/udev/hwdb.d
    cp 61-sensor-yogabook.hwdb $out/lib/udev/hwdb.d
  '';
}
