{ stdenv, src }: stdenv.mkDerivation
{
  name = "slate";
  src = "${src}/Slate.tar.gz";
  installPhase =
  ''
    mkdir -p $out/share/yakuake/skins/Slate
    cp -r * $out/share/yakuake/skins/Slate
  '';
}
