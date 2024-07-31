{ stdenv, cmake, src }: stdenv.mkDerivation
{
  name = "cppcoro";
  inherit src;
  nativeBuildInputs = [ cmake ];
  patches = [ ./cppcoro-include-utility.patch ];
}
