{ stdenv, src }: stdenv.mkDerivation
{
  name = "date";
  inherit src;
  phases = [ "installPhase" ];
  installPhase =
  ''
    runHook preInstall
    mkdir -p $out
    cp -r $src/{include,src} $out
    runHook postInstall
  '';
}
