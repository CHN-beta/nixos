{
  stdenv, fetchFromGitHub, cmake, pkg-config,
  gnuplot, libjpeg, libtiff, zlib, libpng, lapack, blas, fftw, opencv, nodesoup, cimg
}: stdenv.mkDerivation rec
{
  pname = "matplotplusplus";
  version = "1.2.0";
  src = fetchFromGitHub
  {
    owner = "alandefreitas";
    repo = "matplotplusplus";
    rev = "v${version}";
    sha256 = "mYXAB1AbCtcd2rEuluJN6hDKE9+AowodjJt2pdyntes=";
  };
  cmakeFlags =
  [
    "-DBUILD_SHARED_LIBS=ON" "-DMATPLOTPP_BUILD_SHARED_LIBS=ON" "-DMATPLOTPP_BUILD_EXAMPLES=OFF"
    "-DMATPLOTPP_WITH_SYSTEM_NODESOUP=ON" "-DMATPLOTPP_WITH_SYSTEM_CIMG=ON"
  ];
  buildInputs = [ gnuplot libjpeg libtiff zlib libpng lapack blas fftw opencv nodesoup cimg ];
  nativeBuildInputs = [ cmake pkg-config ];
}
