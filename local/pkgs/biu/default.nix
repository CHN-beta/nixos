{
  stdenv, cmake,
  magic-enum, fmt, boost, eigen, range-v3, nameof, zpp-bits
}: stdenv.mkDerivation rec
{
  name = "biu";
  src = ./.;
  buildInputs = [ magic-enum fmt boost eigen range-v3 nameof zpp-bits ];
  propagatedBuildInputs = buildInputs;
  nativeBuildInputs = [ cmake ];
}
