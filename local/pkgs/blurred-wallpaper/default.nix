{ stdenv, src }: stdenv.mkDerivation
{
  name = "blurred-wallpaper";
  inherit src;
  phases = [ "installPhase" ];
  installPhase =
  ''
    mkdir -p $out/share/plasma/wallpapers/a2n.blur
    cp -r $src/* $out/share/plasma/wallpapers/a2n.blur
  '';
}
