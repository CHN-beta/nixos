{
  stdenv, src, buildFHSEnv,
  libxml2, libz, freeglut, libGLU, xorg, alsa-lib, freetype, wayland, fontconfig, libxkbcommon, systemd, numactl, nss,
  at-spi2-atk, libxcrypt-legacy, glibtool, tbb, libxslt, glib, gtk3, libedit, gdbm, ncurses5, mesa, libdrm, xmlsec
}:
let unwrapped = stdenv.mkDerivation
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
in buildFHSEnv
{
  name = "lumerical";
  passthru = { inherit unwrapped; };
  targetPkgs = pkgs: with pkgs; [ unwrapped libxml2 xmlsec libz libGL stdenv.cc.cc.lib
  
  freeglut libGLU alsa-lib freetype fontconfig libxkbcommon systemd numactl nss
   libxcrypt-legacy glibtool tbb libxslt glib gtk3 libedit gdbm ncurses5 mesa libdrm xmlsec libsForQt5.full libsForQt5.qt5.qtnetworkauth
   ]
    ++ (with xorg; [
     libX11 libXt libICE libXdamage libXfixes xcbutilwm xcbutilimage xcbutilkeysyms xcbutilrenderutil libXcursor
    libXcomposite libXtst libXft libXScrnSaver libSM libXext ]);
  runScript = "/opt/bin/fdtd-solutions-app";
  # runScript = "/opt/bin/launcher";
}

# stdenv.mkDerivation
# {
#   name = "lumerical";
#   inherit src;
#   buildInputs =
#   [
#     stdenv.cc.cc libxml2 libz freeglut libGLU alsa-lib freetype wayland fontconfig libxkbcommon systemd numactl nss
#     libxcrypt-legacy glibtool tbb libxslt glib gtk3 libedit gdbm ncurses5 mesa libdrm xmlsec
#   ]
#     ++ (with xorg;
#     [
#       libX11 libXt libICE libXdamage libXfixes xcbutilwm xcbutilimage xcbutilkeysyms xcbutilrenderutil libXcursor # libXcomposite libXtst libXft libXScrnSaver
#     ]);
#   dontConfigure = true;
#   dontBuild = true;
#   installPhase =
#   ''
#     mkdir -p $out
#     cp -r $src/v231 $out/opt
#     chmod -R +w $out
#     rm $out/opt/{bin/itkdb-bridge,lib/libxmlsec*}
#   '';
#   autoPatchelfIgnoreMissingDeps = [ "libmpi.so.12" "libmpi.so.40" "libmex.so" "iboaDesign.so" ];
# }
