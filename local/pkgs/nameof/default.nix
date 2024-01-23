{ lib, stdenv, src }: stdenv.mkDerivation
{
  name = "nameof";
  inherit src;
  phases = [ "installPhase" ];
  installPhase =
  ''
    runHook preInstall
    mkdir -p $out
    cp -r $src/include $out
    runHook postInstall
  '';
}
