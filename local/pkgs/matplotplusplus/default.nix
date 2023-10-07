{
  stdenv, fetchFromGitHub, cmake, pkg-config, substituteAll,
  gnuplot, libjpeg, libtiff, zlib, libpng, lapack, blas, fftw, opencv, nodesoup, cimg, glfw, libGL, python3
}:
let
  glad = fetchFromGitHub
  {
    owner = "Dav1dde";
    repo = "glad";
    rev = "v0.1.36";
    sha256 = "FtkPz0xchwmqE+QgS+nSJVYaAfJSTUmZsObV/IPypVQ=";
  };
  python = python3.withPackages (pythonPackages: with pythonPackages; [ glad ]);
in stdenv.mkDerivation rec
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
  patches = [(substituteAll { src = ./add-glad.patch; inherit glad; })];
  buildInputs = [ gnuplot libjpeg libtiff zlib libpng lapack blas fftw opencv nodesoup cimg glfw libGL python ];
  nativeBuildInputs = [ cmake pkg-config python ];
}
