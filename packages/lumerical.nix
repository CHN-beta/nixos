{
  stdenv, src, autoPatchelfHook,
  libxml2, libz, freeglut, libGLU, xorg, alsa-lib, freetype, wayland, fontconfig, libxkbcommon, systemd, numactl, nss,
  at-spi2-atk, libxcrypt-legacy, glibtool, tbb, libxslt, glib, gtk3, libedit, gdbm, ncurses5, mesa, libdrm, xmlsec
}: stdenv.mkDerivation
{
  name = "lumerical";
  inherit src;
  buildInputs =
    [ stdenv.cc.cc libxml2 libz freeglut libGLU alsa-lib freetype wayland fontconfig libxkbcommon systemd numactl nss libxcrypt-legacy glibtool tbb libxslt glib gtk3 libedit gdbm ncurses5 mesa libdrm xmlsec ]
    ++ (with xorg; [ libX11 libXt libICE libXdamage libXfixes xcbutilwm xcbutilimage xcbutilkeysyms xcbutilrenderutil libXcursor libXcomposite libXtst libXft libXScrnSaver ]);
  nativeBuildInputs = [ autoPatchelfHook ];
  dontConfigure = true;
  dontBuild = true;
  installPhase =
  ''
    mkdir -p $out
    cp -r $src/v231 $out/opt
    chmod -R +w $out
    rm $out/opt/{bin/itkdb-bridge,lib/libxmlsec*}
  '';
  autoPatchelfIgnoreMissingDeps = [ "libmpi.so.12" "libmpi.so.40" "libmex.so" "iboaDesign.so" ];
}
