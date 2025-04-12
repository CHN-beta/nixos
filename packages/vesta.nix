{
  lib, stdenv, fetchurl, autoPatchelfHook, wrapGAppsHook, makeWrapper, src,
  glib, gtk2, xorg, libGLU, gtk3, writeShellScript, gsettings-desktop-schemas, xdg-utils, webkitgtk, jdk
}:

stdenv.mkDerivation
{
  pname = "vesta";
  inherit (src) src version;
  nativeBuildInputs =
    [ autoPatchelfHook wrapGAppsHook makeWrapper glib gtk2 xorg.libXxf86vm libGLU gtk3 xorg.libXtst webkitgtk jdk ];
  unpackPhase = "tar -xf $src";
  installPhase =
  ''
    echo $out
    mkdir -p $out/share/applications
    cp ${src.desktopFile} $out/share/applications/vesta.desktop
    sed -i "s|Exec=.*|Exec=$out/bin/vesta|" $out/share/applications/vesta.desktop
    sed -i "s|Icon=.*|Icon=$out/opt/VESTA-gtk3/img/logo.png|" $out/share/applications/vesta.desktop

    mkdir -p $out/opt
    cp -r VESTA-gtk3-x86_64 $out/opt/VESTA-gtk3-x86_64

    mkdir -p $out/bin
    makeWrapper $out/opt/VESTA-gtk3-x86_64/VESTA $out/bin/vesta

    patchelf --remove-needed libjawt.so $out/opt/VESTA-gtk3-x86_64/PowderPlot/libswt-awt-gtk-3346.so
  '';
}
