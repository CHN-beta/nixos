{
  stdenv, cmake,
  magic-enum, fmt, boost, eigen, range-v3, nameof
}: stdenv.mkDerivation rec
{
  name = "biu";
  src = ./.;
  buildInputs = [ magic-enum fmt boost eigen range-v3 nameof ];
  propagatedBuildInputs = buildInputs;
  nativeBuildInputs = [ cmake ];
}
