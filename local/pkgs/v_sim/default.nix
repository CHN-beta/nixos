{
  stdenv, lib, fetchFromGitLab,
  wrapGAppsHook, autoreconfHook, autoconf, libtool, intltool, gettext, automake, gtk-doc, pkg-config, gfortran, libxslt,
  glib, gtk3, epoxy, libyaml
}:
stdenv.mkDerivation
{
  pname = "v_sim";
  version = "3.8.0_p20230824";
  src = fetchFromGitLab
  {
    owner = "l_sim";
    repo = "v_sim";
    rev = "8abc67b56795c19a8e2357d442b556c71d2441cb";
    sha256 = "KQNd3BGvkZVsfIPVLEEMBptiFQYeCbWGR28ds2Y+w2Y=";
  };
  buildInputs = [ glib gtk3 epoxy libyaml ];
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
