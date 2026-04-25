{ stdenv, cmake, biu }: stdenv.mkDerivation
{
  name = "debug-kernel310-hang";
  src = ./.;
  buildInputs = [ biu ];
  nativeBuildInputs = [ cmake ];
}
