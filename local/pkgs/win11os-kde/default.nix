{ lib, stdenv, src }: stdenv.mkDerivation
{
  name = "win11os-kde";
  inherit src;
  installPhase =
  ''
    mkdir -p $out/share/aurorae/themes
    cp -r $src/aurorae/* $out/share/aurorae/themes
    mkdir -p $out/share/color-schemes
    cp -r $src/color-schemes/*.colors $out/share/color-schemes
    mkdir -p $out/share/Kvantum
    cp -r $src/Kvantum/* $out/share/Kvantum
    mkdir -p $out/share/plasma/desktoptheme
    cp -r $src/plasma/desktoptheme/* $out/share/plasma/desktoptheme
    mkdir -p $out/share/plasma/look-and-feel
    cp -r $src/plasma/look-and-feel/* $out/share/plasma/look-and-feel
    mkdir -p $out/share/wallpapers
    cp -r $src/wallpaper/* $out/share/wallpapers
  '';
}
