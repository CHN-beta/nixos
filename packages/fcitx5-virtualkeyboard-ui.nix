{
  lib, stdenv, src, substituteAll,
  cmake, extra-cmake-modules, fcitx5, gettext, fmt, cairo, expat, libXdmcp, pango, pcre2, util-linux, libselinux,
  libsepol, fribidi, libthai, libdatrie, xorg, kdePackages, egl-wayland, eglexternalplatform, gdk-pixbuf, lerc
}: stdenv.mkDerivation
{
  name = "fcitx5-virtualkeyboard-ui";
  inherit src;
  cmakeFlags = [ "-DWAYLAND_PROTOCOLS_PKGDATADIR=${kdePackages.wayland-protocols}/share/wayland-protocols" ];

  nativeBuildInputs = [ cmake extra-cmake-modules ];
  buildInputs =
  [
    fcitx5 gettext fmt cairo expat libXdmcp pango pcre2 util-linux libselinux libsepol fribidi libthai libdatrie
    xorg.xcbutil xorg.xcbutilwm xorg.xcbutilkeysyms kdePackages.wayland kdePackages.wayland-protocols egl-wayland
    eglexternalplatform gdk-pixbuf lerc
  ];
}
