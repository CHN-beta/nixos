{ lib, stdenv, fetchFromGitHub, fetchurl, cmake }: stdenv.mkDerivation rec
{
  pname = "chromiumos-touch-keyboard";
  version = "1.4.1";
  src = fetchFromGitHub
  {
    owner = "CHN-beta";
    repo = "chromiumos_touch_keyboard";
    rev = "32b72240ccac751a1b983152f65aa5b19503ffcf";
    sha256 = "eFesDSBS2VzTOVfepgXYGynWvkrCSdCV9C/gcG/Ocbg=";
  };
  cmakeFlags = [ "-DCMAKE_CXX_FLAGS=-Wno-error=stringop-truncation" ];
  nativeBuildInputs = [ cmake ];
  postInstall =
  ''
    cp $out/etc/touch_keyboard/layouts/YB1-X9x-pc105.csv $out/etc/touch_keyboard/layout.csv
  '';
}
