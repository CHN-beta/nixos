{ stdenv, cmake, src, windows, lib }: stdenv.mkDerivation
{
  name = "concurrencpp";
  inherit src;
  buildInputs = lib.optionals stdenv.hostPlatform.isMinGW [ windows.pthreads ];
  nativeBuildInputs = [ cmake ];
}
