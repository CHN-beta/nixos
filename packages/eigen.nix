{ lib, stdenv, cmake, src }: stdenv.mkDerivation
{
  name = "eigen";
  inherit src;
  nativeBuildInputs = [ cmake ];
}
