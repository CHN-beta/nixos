{
  lib, stdenv, requireFile, src,
  boost, nghttp2, brotli, nameof, cppcoro, libbacktrace, fmt, date, openssl
}: stdenv.mkDerivation
{
  name = "mirism";
  inherit src;
  buildInputs = [ boost nghttp2 brotli nameof cppcoro libbacktrace fmt date openssl ];
  buildPhase =
  ''
    runHook preBuild
    make ng01 beta
    runHook postBuild
  '';
  installPhase =
  ''
    runHook preInstall
    mkdir -p $out/bin
    cp build/{ng01,beta} $out/bin
    runHook postInstall
  '';
}
