{
  lib, stdenv, fetchsvn, xorg, libdrm
}:

stdenv.mkDerivation rec
{
  pname = "12to11";
  version = "193";
  src = fetchsvn
  {
    url = "svn://svn.code.sf.net/p/twelveto11/code";
    rev = version;
    sha256 = "12csy55f2xxj03c5b60dvip68mz8cggic6751y3hvj22ar4ncaaj";
  };
  postPatch =
  ''
    for i in *.c
    do
      sed -i -e "s|#include <drm_fourcc.h>|#include <libdrm/drm_fourcc.h>|" $i
    done
    for i in tests/*.c
    do
      sed -i -e "s|#include <drm/drm_fourcc.h>|#include <libdrm/drm_fourcc.h>|" $i
    done
  '';

  nativeBuildInputs = [  ];
  buildInputs = [ xorg.imake libdrm.dev ];
}
