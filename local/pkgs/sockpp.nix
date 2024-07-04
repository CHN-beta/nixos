{ stdenv, src, cmake, pkg-config }: stdenv.mkDerivation
{
  name = "sockpp";
  inherit src;
  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [];
}
