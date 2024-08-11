{
  stdenv, src, cmake, pkg-config,
  libjpeg, libtiff, zlib, libpng
}: stdenv.mkDerivation
{
  name = "matplotplusplus";
  inherit src;
  cmakeFlags = [ "-DMATPLOTPP_BUILD_EXAMPLES=OFF" "-DMATPLOTPP_BUILD_TESTS=OFF" ];
  buildInputs = [ libjpeg libtiff zlib libpng ];
  nativeBuildInputs = [ cmake pkg-config ];
}
