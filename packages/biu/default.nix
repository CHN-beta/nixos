{
  stdenv, cmake, lib,
  magic-enum, fmt, boost, eigen, range-v3, nameof, zpp-bits, highfive, tgbot-cpp, libbacktrace, hdf5, concurrencpp,
  pocketfft, yaml-cpp, glaze, cpptrace
}: stdenv.mkDerivation rec
{
  name = "biu";
  src = ./.;
  buildInputs =
  [
    magic-enum fmt boost range-v3 nameof zpp-bits eigen libbacktrace hdf5
    concurrencpp pocketfft yaml-cpp glaze (highfive.override { inherit boost; }) (tgbot-cpp.override { inherit boost; })
    cpptrace
  ];
  propagatedBuildInputs = buildInputs;
  nativeBuildInputs = [ cmake ];
  doCheck = true;
}
