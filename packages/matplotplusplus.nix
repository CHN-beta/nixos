{
  stdenv, src, cmake, pkg-config, substituteAll
}: stdenv.mkDerivation
{
  name = "matplotplusplus";
  inherit src;
  cmakeFlags = [ "-DBUILD_SHARED_LIBS=ON" "-DMATPLOTPP_BUILD_EXAMPLES=OFF" ];
  nativeBuildInputs = [ cmake pkg-config ];
}
