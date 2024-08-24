{
  stdenv, cmake, pkg-config, version ? null,
  yaml-cpp, eigen, fmt, concurrencpp, highfive, tbb, matplotplusplus, biu, zpp-bits
}: stdenv.mkDerivation
{
  name = "ufo";
  src = ./.;
  buildInputs = [ yaml-cpp eigen fmt concurrencpp highfive tbb matplotplusplus biu zpp-bits ];
  nativeBuildInputs = [ cmake pkg-config ];
  doCheck = true;
}
