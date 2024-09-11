{
  stdenv, cmake, pkg-config, version ? null,
  tbb, matplotplusplus, biu
}: stdenv.mkDerivation
{
  name = "ufo";
  src = ./.;
  buildInputs = [ tbb matplotplusplus biu ];
  nativeBuildInputs = [ cmake pkg-config ];
  doCheck = true;
}
