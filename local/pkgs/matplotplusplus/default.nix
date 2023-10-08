{
  stdenv, fetchFromGitHub, cmake, pkg-config, substituteAll,
  gnuplot, libjpeg, libtiff, zlib, libpng, lapack, blas, fftw, opencv, nodesoup, cimg, glfw, libGL, python3, glad
}: stdenv.mkDerivation
{
  pname = "matplotplusplus";
  version = "1.2.0";
  src = fetchFromGitHub
  {
    owner = "alandefreitas";
    repo = "matplotplusplus";
    rev = "a40344efa9dc5ea0c312e6e9ef4eb7238d98dc12";
    sha256 = "6/dH/Rl2aAb8b+Ji5LwzkC+GWPOCBnYCrjy0qk8u/+I=";
  };
  cmakeFlags =
  [
    "-DBUILD_SHARED_LIBS=ON" "-DMATPLOTPP_BUILD_SHARED_LIBS=ON" "-DMATPLOTPP_BUILD_EXAMPLES=OFF"
    "-DMATPLOTPP_WITH_SYSTEM_NODESOUP=ON" "-DMATPLOTPP_WITH_SYSTEM_CIMG=ON"
    "-DMATPLOTPP_BUILD_EXPERIMENTAL_OPENGL_BACKEND=ON" "-DGLAD_REPRODUCIBLE=ON"
  ];
  buildInputs = [ gnuplot libjpeg libtiff zlib libpng lapack blas fftw opencv nodesoup cimg glfw libGL glad ];
  nativeBuildInputs = [ cmake pkg-config python3 ];
}
