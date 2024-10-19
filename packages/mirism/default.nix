{ stdenv, cmake, pkg-config, biu }: stdenv.mkDerivation
{
  name = "mirism";
  src = ./.;
  buildInputs = [ biu ];
  nativeBuildInputs = [ cmake pkg-config ];
}
