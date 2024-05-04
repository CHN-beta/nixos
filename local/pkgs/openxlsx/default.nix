{ stdenv, src, cmake, pkg-config }: stdenv.mkDerivation
{
  name = "openxlsx";
  inherit src;
  nativeBuildInputs = [ cmake pkg-config ];
  cmakeFlags =
  [
    "-DOPENXLSX_CREATE_DOCS=OFF" "-DOPENXLSX_BUILD_SAMPLES=OFF" "-DOPENXLSX_BUILD_TESTS=OFF"
    "-DOPENXLSX_BUILD_BENCHMARKS=OFF"
  ];
}
