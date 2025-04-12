{
  lib, stdenv, requireFile, src,
  boost, nghttp2, brotli, nameof, cppcoro, tgbot-cpp, libbacktrace, fmt, date
}: stdenv.mkDerivation
{
  name = "mirism";
  buildInputs = [ boost nghttp2.dev brotli nameof cppcoro tgbot-cpp libbacktrace fmt date ];
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
