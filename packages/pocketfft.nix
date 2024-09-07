{ lib, stdenv, src }: stdenv.mkDerivation
{
  name = "pocketfft";
  inherit src;
  phases = [ "installPhase" ];
  installPhase =
  ''
    runHook preInstall
    mkdir -p $out/include
    cp -r $src/pocketfft_hdronly.h $out/include/pocketfft.h
    runHook postInstall
  '';
}
