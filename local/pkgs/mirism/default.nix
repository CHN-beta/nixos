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
    sha256 = "1q3f4q4ln9dz68dfc35jybgv861f7acqiiykkm7jxviz8jdgn8c7";
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
