{
  stdenv, src, buildFHSEnv, writeScript, autoPatchelfHook,
  libxml2, libz, freeglut, libGLU, xorg, alsa-lib, freetype, wayland, fontconfig, libxkbcommon, systemd, numactl, nss,
  at-spi2-atk, libxcrypt-legacy, glibtool, tbb, libxslt, glib, gtk3, libedit, gdbm, ncurses5, mesa, libdrm, xmlsec,
  libsForQt5
}:
let
  unwrapped = stdenv.mkDerivation
  {
    name = "lumerical-unwrapped";
    inherit src;
    dontConfigure = true;
    dontBuild = true;
    installPhase =
    ''
      mkdir -p $out
      cp -r $src/v231 $out/opt
      chmod -R +w $out
      rm $out/opt/{bin/itkdb-bridge,lib/libxmlsec*,lib/libQt5*}
    '';
    dontFixup = true;
  };
  startScript = writeScript "fdtd"
  ''
    export XDG_SESSION_TYPE=x11
    /opt/bin/fdtd-solutions-app "$@"
  '';
  raw = stdenv.mkDerivation
  {
    name = "lumerical";
    inherit src;
    buildInputs =
    [
      stdenv.cc.cc libxml2 libz freeglut libGLU alsa-lib freetype wayland fontconfig libxkbcommon systemd numactl nss
      libxcrypt-legacy glibtool tbb libxslt glib gtk3 libedit gdbm ncurses5 mesa libdrm xmlsec
    ]
    ++ (with xorg; [
      libX11 libXt libICE libXdamage libXfixes xcbutilwm xcbutilimage xcbutilkeysyms xcbutilrenderutil libXcursor
      libXcomposite libXtst libXft libXScrnSaver
    ])
    ++ (with libsForQt5; [ full qt5.qtnetworkauth qt5.qtimageformats qt5.qtquickcontrols2 ]);
    nativeBuildInputs = [ autoPatchelfHook libsForQt5.wrapQtAppsHook ];
    dontConfigure = true;
    dontBuild = true;
    installPhase =
    ''
      mkdir -p $out
      cp -r $src/v231 $out/opt
      chmod -R +w $out
      rm -r $out/opt/{bin/itkdb-bridge,bin/plugins/imageformats,bin/QtQuick*,lib/libxmlsec*,lib/libQt5*}
    '';
    autoPatchelfIgnoreMissingDeps = [ "libmpi.so.12" "libmpi.so.40" "libmex.so" "iboaDesign.so" ];
  };
in buildFHSEnv
{
  name = "lumerical";
  passthru = { inherit unwrapped raw; };
  targetPkgs = pkgs: with pkgs;
  [
    unwrapped libxml2 xmlsec libz libGL stdenv.cc.cc.lib
    freeglut libGLU alsa-lib freetype fontconfig libxkbcommon systemd numactl nss
    libxcrypt-legacy glibtool tbb libxslt glib gtk3 libedit gdbm ncurses5 mesa libdrm xmlsec
    libsForQt5.full libsForQt5.qt5.qtnetworkauth
  ]
  ++ (with xorg; [
    libX11 libXt libICE libXdamage libXfixes xcbutilwm xcbutilimage xcbutilkeysyms xcbutilrenderutil libXcursor
    libXcomposite libXtst libXft libXScrnSaver libSM libXext
  ]);
  runScript = startScript;
}
