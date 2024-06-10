{
  stdenv, cmake, pkg-config,
  yaml-cpp, eigen, fmt, concurrencpp, highfive, tbb, glad, matplotplusplus, biu, zpp-bits
}: stdenv.mkDerivation
{
  name = "ufo";
  src = ./.;
  buildInputs = [ yaml-cpp eigen fmt concurrencpp highfive tbb glad matplotplusplus biu zpp-bits ];
  nativeBuildInputs = [ cmake pkg-config ];
}
