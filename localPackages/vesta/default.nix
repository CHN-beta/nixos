{ lib, stdenv, fetchurl, autoPatchelfHook, gtk2, xorg, libGLU, gtk3, openjdk }:

stdenv.mkDerivation rec
{
	pname = "vesta";
	version = "3.5.5";
	src = fetchurl
	{
		url = "https://jp-minerals.org/vesta/archives/${version}/VESTA-gtk3.tar.bz2";
		sha256 = "sRzQNJA7+hsjLWmykqe6bH0p1/aGEB8hCuxCyPzxYHs=";
	};
	desktopFile = fetchurl
	{
		url = "https://aur.archlinux.org/cgit/aur.git/plain/VESTA.desktop?h=vesta&id=4fae08afc37ee0fd88d14328cf0d6b308fea04d1";
		sha256 = "Tq4AzQgde2KIWKA1k6JlxvdphGG9JluHMZjVw0fBUeQ=";
	};

	nativeBuildInputs = [ autoPatchelfHook gtk2 xorg.libXxf86vm libGLU gtk3 xorg.libXtst openjdk ];
	# buildInputs = [ makeWrapper ];

	unpackPhase = "tar -xf ${src}";

  installPhase =
	''
		mkdir -p $out/share/applications
		cp ${desktopFile} $out/share/applications/vesta.desktop
		sed -i "s|Exec=.*|Exec=$out/bin/vesta|" $out/share/applications/vesta.desktop

		mkdir -p $out/opt
		cp -r VESTA-gtk3 $out/opt/VESTA-gtk3

		mkdir -p $out/bin
		ln -s $out/opt/VESTA-gtk3/VESTA $out/bin/vesta

		patchelf --remove-needed libjawt.so $out/opt/VESTA-gtk3/PowderPlot/libswt-awt-gtk-3346.so
	'';
}
