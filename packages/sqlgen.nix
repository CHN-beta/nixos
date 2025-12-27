{ stdenv, src, cmake, pkg-config, postgresql, reflectcpp }: stdenv.mkDerivation
{
  name = "sqlgen";
  inherit src;
  nativeBuildInputs = [ cmake pkg-config ];
  buildInputs = [ postgresql reflectcpp ];
  cmakeFlags = [ "-DSQLGEN_USE_VCPKG=OFF" "-DSQLGEN_SQLITE3=OFF" "-DBUILD_SHARED_LIBS=ON" ];
}
