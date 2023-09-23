{
  stdenv, fetchFromGitHub, cmake, pkg-config,
  gnuplot, libjpeg, libtiff, zlib, libpng, lapack, blas, fftw, opencv
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
  cmakeFlags = [ "-DMATPLOTPP_BUILD_SHARED_LIBS=ON" "-DMATPLOTPP_BUILD_EXAMPLES=OFF" ];
  buildInputs = [ gnuplot libjpeg libtiff zlib libpng lapack blas fftw opencv ];
  nativeBuildInputs = [ cmake pkg-config ];
}
