{
  stdenv,
  src,
  cmake,
  pkg-config,
  libzip,
  pugixml,
}:
stdenv.mkDerivation {
  name = "openxlsx";
  inherit src;
  nativeBuildInputs = [
    cmake
    pkg-config
  ];
  propagatedBuildInputs = [
    libzip
    pugixml
  ];
  cmakeFlags = [
    "-DOPENXLSX_CREATE_DOCS=OFF"
    "-DOPENXLSX_BUILD_SAMPLES=OFF"
    "-DOPENXLSX_BUILD_TESTS=OFF"
    "-DOPENXLSX_BUILD_BENCHMARKS=OFF"
    "-DOPENXLSX_ENABLE_LIBZIP=ON"
  ];
  patches = [ ./openxlsx.patch ];
}
