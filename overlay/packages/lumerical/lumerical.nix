{
  stdenv,
  src,
  buildFHSEnv,
  writeScript,
  autoPatchelfHook,
  writeShellScriptBin,
  libz,
  freeglut,
  libGLU,
  alsa-lib,
  freetype,
  wayland,
  fontconfig,
  libxkbcommon,
  systemd,
  numactl,
  nss,
  at-spi2-atk,
  libxcrypt-legacy,
  glibtool,
  tbb,
  libxslt,
  glib,
  gtk3,
  libedit,
  gdbm,
  ncurses5,
  mesa,
  libdrm,
  xmlsec,
  libsForQt5,
  mpi,
  libGL,
  xz,
  libgbm,
  libxml2_13,
  libXdamage,
  libXfixes,
  libXt,
  libICE,
  libSM,
  xcbutilwm,
  libXft,
  xcbutilimage,
  xcbutilkeysyms,
  xcbutilrenderutil,
  libXcomposite,
  libXcursor,
  libXtst,
  libXScrnSaver,
}:
let
  unwrapped = stdenv.mkDerivation {
    name = "lumerical-unwrapped";
    inherit src;
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      mkdir -p $out
      cp -r $src/v231 $out/opt
      chmod -R +w $out
      rm $out/opt/{bin/itkdb-bridge,lib/libxmlsec*,lib/libQt5*}
    '';
    dontFixup = true;
  };
  startScript = writeScript "fdtd" ''
    export XDG_SESSION_TYPE=x11
    /opt/bin/fdtd-solutions-app "$@"
  '';
  cmd-unwrapped = stdenv.mkDerivation {
    name = "lumerical";
    inherit src;
    buildInputs = [
      stdenv.cc.cc
      libz
      libGLU
      libGL
      mpi
      libxml2_13
      xmlsec
      freeglut
      fontconfig
      libxkbcommon
      systemd
      tbb
      xz
      glib
      libxcrypt-legacy
      at-spi2-atk
      gtk3
      libdrm
      alsa-lib
      ncurses5
      libgbm
      libedit
      gdbm
      libXdamage
      libXfixes
      libXt
      libICE
      libSM
      xcbutilwm
      libXft
      xcbutilimage
      xcbutilkeysyms
      xcbutilrenderutil
      libXcomposite
      libXcursor
      libXtst
      libXScrnSaver
      libsForQt5.qtwayland
    ];
    nativeBuildInputs = [
      autoPatchelfHook
      libsForQt5.wrapQtAppsHook
    ];
    dontConfigure = true;
    dontBuild = true;
    installPhase = ''
      mkdir -p $out/opt/ansys_inc
      cp -r $src/v231 $out/opt/ansys_inc
      chmod -R +w $out

      # old library that have missing dependencies
      rm -r $out/opt/ansys_inc/v231/lib/libxmlsec*

      # unused binary, need a lot of libraries
      rm $out/opt/ansys_inc/v231/bin/itkdb-bridge
      rm -r $out/opt/ansys_inc/v231/api/matlab

      addAutoPatchelfSearchPath $out/ansys_inc/v231/opt/lib
    '';
    autoPatchelfIgnoreMissingDeps = [ "libmpi.so.12" ];
  };
  cmd = writeShellScriptBin "lumerical" ''
    export PATH="${mpi}/bin:${cmd-unwrapped}/opt/ansys_inc/v231/bin:$PATH"
    exec "$@"
  '';
in
buildFHSEnv {
  name = "lumerical";
  passthru = { inherit unwrapped cmd-unwrapped cmd; };
  targetPkgs =
    pkgs: with pkgs; [
      unwrapped
      libxml2
      xmlsec
      libz
      libGL
      stdenv.cc.cc.lib
      freeglut
      libGLU
      alsa-lib
      freetype
      fontconfig
      libxkbcommon
      systemd
      numactl
      nss
      libxcrypt-legacy
      glibtool
      tbb
      libxslt
      glib
      gtk3
      libedit
      gdbm
      ncurses5
      mesa
      libdrm
      xmlsec
      libsForQt5.qt5.qtnetworkauth
      mpi
      libX11
      libXt
      libICE
      libXdamage
      libXfixes
      xcbutilwm
      xcbutilimage
      xcbutilkeysyms
      xcbutilrenderutil
      libXcursor
      libXcomposite
      libXtst
      libXft
      libXScrnSaver
      libSM
      libXext
    ];
  runScript = startScript;
}
