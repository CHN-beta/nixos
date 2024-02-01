{
  lib, stdenv, requireFile,
  boost, nghttp2, brotli, nameof, cppcoro, tgbot-cpp, libbacktrace, fmt, date
}: stdenv.mkDerivation rec
{
  name = "mirism";
  # nix-store --query --hash $(nix store add-path . --name 'mirism')
  src = requireFile
  {
    inherit name;
    sha256 = "0f50pvdafhlmrlbf341mkp9q50v4ld5pbx92d2w1633f18zghbzf";
    hashMode = "recursive";
    message = "Source file not found.";
  };
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
