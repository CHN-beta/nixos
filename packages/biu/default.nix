{
  stdenv, cmake, lib,
  magic-enum, fmt, boost, eigen, range-v3, nameof, zpp-bits, highfive, tgbot-cpp, hdf5, concurrencpp,
  pocketfft, yaml-cpp, glaze, cpptrace, bzip2, xz, zlib, zstd
}: stdenv.mkDerivation rec
{
  name = "biu";
  src = ./.;
  buildInputs = [ magic-enum fmt boost range-v3 nameof zpp-bits concurrencpp pocketfft yaml-cpp bzip2 xz zlib zstd ]
    ++ lib.optionals stdenv.hostPlatform.isLinux
    [
      eigen hdf5 (highfive.override { inherit boost; }) (tgbot-cpp.override { inherit boost; }) cpptrace glaze
    ];
  propagatedBuildInputs = buildInputs;
  nativeBuildInputs = [ cmake ];
  doCheck = true;
}
