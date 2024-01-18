{ lib, stdenv, steam-run, fetchurl, writeShellScript }:
let
  typora-dist = stdenv.mkDerivation rec
  {
    pname = "typora-dist";
    version = "1.8.2-dev";
    src = fetchurl
    {
      url = "https://download.typora.io/linux/typora_${version}_amd64.deb";
      sha256 = "0abi9m8h8k0228ajag26lxk756a7aqqixg608k85gnkdmibnq6mv";
    };

    dontFixup = true;

    unpackPhase =
    ''
      ar x ${src}
      tar xf data.tar.xz
    '';
    installPhase =
    ''
      mkdir -p $out
      mv usr/share $out
    '';
  };
in stdenv.mkDerivation rec
{
  pname = "typora";
  inherit (typora-dist) version;
  BuildInputs = [ typora-dist steam-run ];
  startScript = writeShellScript "typora" "${steam-run}/bin/steam-run ${typora-dist}/share/typora/Typora $@";
  phases = [ "installPhase" ];
  installPhase =
  ''
    mkdir -p $out/bin $out/share/applications
    ln -s ${startScript} $out/bin/typora
    cp ${typora-dist}/share/applications/typora.desktop $out/share/applications
    sed -i "s|Exec=.*|Exec=${startScript} %U|g" $out/share/applications/typora.desktop
    sed -i "s|Icon=.*|Icon=${typora-dist}/share/icons/hicolor/256x256/apps/typora.png|g" \
      $out/share/applications/typora.desktop
  '';
}
