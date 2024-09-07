{
  stdenv, cmake, lib,
  magic-enum, fmt, boost, eigen, range-v3, nameof, zpp-bits, highfive, tgbot-cpp, libbacktrace, hdf5, concurrencpp,
  pocketfft
}: stdenv.mkDerivation rec
{
  name = "biu";
  src = ./.;
  buildInputs =
  [
    magic-enum fmt boost range-v3 nameof zpp-bits eigen highfive tgbot-cpp libbacktrace hdf5
    concurrencpp pocketfft
  ];
  propagatedBuildInputs = buildInputs;
  nativeBuildInputs = [ cmake ];
  doCheck = true;
}
