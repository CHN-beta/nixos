{ stdenv, src, cmake, pkg-config, sqlite }: stdenv.mkDerivation
{
  name = "sqlite-orm";
  inherit src;
  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [ sqlite ];
}
