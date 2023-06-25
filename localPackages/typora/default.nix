{ lib, stdenv, steam, fetchurl, writeShellScript }:
let
	typora-dist = stdenv.mkDerivation rec
	{
		pname = "typora-dist";
		version = "1.6.6";
		src = fetchurl
		{
			url = "https://download.typora.io/linux/typora_${version}_amd64.deb";
			sha256 = lib.fakeSha256;
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
	steam-run = (steam.override {
    extraPkgs = p: [ license resource ];
    runtimeOnly = true;
  }).run;
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
    cp ${typora-dist}/share/applications/ $out/share/applications/typora.desktop
  '';
}
