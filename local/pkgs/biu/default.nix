{
  stdenv, cmake,
  magic-enum, fmt, boost, eigen, range-v3, nameof
}: stdenv.mkDerivation
{
  name = "biu";
  src = ./.;
  buildInputs = [ magic-enum fmt boost eigen range-v3 nameof ];
  nativeBuildInputs = [ cmake ];
}
