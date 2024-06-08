{ stdenv, src }: stdenv.mkDerivation
{
  name = "blurred-wallpaper";
  inherit src;
  phases = [ "installPhase" ];
  installPhase =
  ''
    mkdir -p $out/share/plasma/wallpapers
    cp -r $src/a2n.blur $out/share/plasma/wallpapers
  '';
}
