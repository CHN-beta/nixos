{
  stdenv, src, cmake, pkg-config, substituteAll,
  gnuplot, libjpeg, libtiff, zlib, libpng, lapack, blas, fftw, opencv, nodesoup, cimg, glfw, libGL, python3, glad
}: stdenv.mkDerivation
{
  name = "matplotplusplus";
  inherit src;
  cmakeFlags =
  [
    "-DMATPLOTPP_BUILD_EXAMPLES=OFF"
    "-DMATPLOTPP_WITH_SYSTEM_NODESOUP=ON" "-DMATPLOTPP_WITH_SYSTEM_CIMG=ON"
    "-DMATPLOTPP_BUILD_EXPERIMENTAL_OPENGL_BACKEND=ON" "-DGLAD_REPRODUCIBLE=ON"
  ];
  buildInputs = [ gnuplot libjpeg libtiff zlib libpng lapack blas fftw opencv nodesoup cimg glfw libGL glad ];
  nativeBuildInputs = [ cmake pkg-config python3 ];
  propagatedBuildInputs = [ libGL glad glfw ];
  propagatedNativeBuildInputs = [ python3 ];
}
