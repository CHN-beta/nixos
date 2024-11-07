{
  stdenv, lib, src,
  wrapGAppsHook, autoreconfHook, autoconf, libtool, intltool, gettext, automake, gtk-doc, pkg-config, gfortran, libxslt,
  glib, gtk3, libepoxy, libyaml
}:
stdenv.mkDerivation
{
  name = "v-sim";
  inherit src;
  buildInputs = [ glib gtk3 libepoxy libyaml ];
  nativeBuildInputs =
  [
    autoreconfHook wrapGAppsHook autoconf libtool intltool gettext automake pkg-config
    gtk-doc gfortran libxslt.bin
  ];
  enableParallelBuilding = true;
  postPatch =
  ''
    ./autogen.sh
  '';
}
