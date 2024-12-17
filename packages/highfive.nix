{ src, stdenv, cmake, hdf5 }: stdenv.mkDerivation
{
  name = "highfive";
  inherit src;
  nativeBuildInputs = [ cmake ];
  buildInputs = [ hdf5 ];
  doCheck = true;
}
