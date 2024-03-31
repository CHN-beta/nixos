{
  stdenv, src, wrapQtAppsHook,
  qtbase, gsettings-qt, pkg-config, kwindowsystem, fcitx5-qt, qmake, wrapGAppsHook, glib
}: stdenv.mkDerivation
{
  name = "kylin-virtual-keyboard";
  inherit src;
  buildInputs = [ qtbase gsettings-qt kwindowsystem fcitx5-qt ];
  nativeBuildInputs = [ wrapQtAppsHook pkg-config qmake wrapGAppsHook glib ];
  qmakeFlags = [ "PREFIX=/" ];
  installFlags = [ "INSTALL_ROOT=$(out)" ];
  postInstall =
  ''
    mv $out/usr/* $out
    rm -rf $out/usr
  '';
}
