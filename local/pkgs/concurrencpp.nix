{ stdenv, cmake, src }: stdenv.mkDerivation
{
  name = "concurrencpp";
  inherit src;
  nativeBuildInputs = [ cmake ];
}
