# http://launchpadlibrarian.net/632309499/pslist_1.4.0-4_all.deb
# https://launchpad.net/ubuntu/+archive/primary/+sourcefiles/pslist/1.4.0-4/pslist_1.4.0.orig.tar.xz
{ stdenv, src, perl, procps }: stdenv.mkDerivation
{
  pname = "pslist";
  inherit (src) version src;
  buildInstall = [ perl procps ];
  installPhase =
  ''
    mkdir -p $out/bin
    cp $src/pslist $out/bin
    ln -s pslist $out/bin/rkill
    ln -s pslist $out/bin/rrenice
    mkdir -p $out/share/man/man1
    cp $src/pslist.1 $out/share/man/man1
    ln -s pslist.1 $out/share/man/man1/rkill.1
    ln -s pslist.1 $out/share/man/man1/rrenice.1

    sed -i 's|/usr/bin/perl|${perl}/bin/perl|' $out/bin/pslist
    sed -i 's|/bin/ps|${procps}/bin/ps|' $out/bin/pslist
  '';
}
