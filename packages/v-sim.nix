{
  stdenv, src, wrapGAppsHook3, autoreconfHook, gfortran, gtk3, intltool, gtk-doc, pkg-config, libepoxy, libyaml,
  libxslt, libGLU, wayland, makeWrapper
}:
stdenv.mkDerivation
{
  name = "v-sim";
  inherit src;
  buildInputs = [ gtk3 libepoxy libyaml libGLU ];
  nativeBuildInputs = [ autoreconfHook wrapGAppsHook3 gfortran intltool gtk-doc pkg-config libxslt makeWrapper ];
  enableParallelBuilding = true;
  postPatch = "./autogen.sh";
  dontWrapGApps = true;
  postFixup = ''wrapProgram $out/bin/v_sim "''${gappsWrapperArgs[@]}" --set GDK_BACKEND x11'';
}
