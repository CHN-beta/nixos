{
  stdenv, cmake, lib,
  magic-enum, fmt, boost, eigen, range-v3, nameof, zpp-bits
}: stdenv.mkDerivation rec
{
  name = "biu";
  src = ./.;
  buildInputs = [ magic-enum fmt boost range-v3 nameof zpp-bits eigen ];
  propagatedBuildInputs = buildInputs;
  nativeBuildInputs = [ cmake ];
  doCheck = true;
}
