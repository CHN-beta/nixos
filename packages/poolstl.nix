{ stdenv, cmake, src }: stdenv.mkDerivation
{
  name = "poolstl";
  inherit src;
  nativeBuildInputs = [ cmake ];
}
