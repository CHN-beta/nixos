{ stdenv, cmake, boost }: stdenv.mkDerivation
{
  name = "debug-kernel310-hang";
  src = ./.;
  buildInputs = [ boost ];
  nativeBuildInputs = [ cmake ];
}
