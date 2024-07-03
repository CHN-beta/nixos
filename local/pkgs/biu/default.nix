{
  stdenv, cmake, lib,
  magic-enum, fmt, boost, eigen, range-v3, nameof, zpp-bits
}: stdenv.mkDerivation rec
{
  name = "biu";
  src = ./.;
  buildInputs = [ magic-enum fmt boost range-v3 nameof zpp-bits ] ++ lib.optional (!stdenv.hostPlatform.isMinGW) eigen;
  propagatedBuildInputs = buildInputs;
  nativeBuildInputs = [ cmake ];
  cmakeFlags = [ "-DBUILD_FOR_WINDOWS=${builtins.toString stdenv.hostPlatform.isMinGW}" ];
  doCheck = true;
}
