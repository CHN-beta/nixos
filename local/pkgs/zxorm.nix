{
  lib, stdenv, cmake, src,
  pkg-config, sqlite
}: stdenv.mkDerivation
{
  name = "zxorm";
  inherit src;
  buildInputs = [ sqlite ];
  nativeBuildInputs = [ cmake pkg-config ];
}
