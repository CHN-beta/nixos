{ stdenv, src, cmake, pkg-config }: stdenv.mkDerivation
{
  name = "date";
  inherit src;
  nativeBuildInputs = [ cmake pkg-config ];
  cmakeFlags = [ "-DBUILD_TZ_LIB=ON" "-DUSE_SYSTEM_TZ_DB=ON" ];
}
