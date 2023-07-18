{
	lib, stdenv, fetchurl, autoPatchelfHook,
	ncurses, xorg
}:
	
stdenv.mkDerivation rec
{
	version = "2023.1";
	pname = "oneapi";

	sourceRoot = ".";
	src = [
		(fetchurl {
			url = "https://registrationcenter-download.intel.com/akdlm/IRC_NAS/7deeaac4-f605-4bcf-a81b-ea7531577c61/l_BaseKit_p_2023.1.0.46401_offline.sh";
			sha256 = "0cn32zqfbjv0vq43g6ap10crnsyk7nldyqpyyzn6g52j5h45g93l";
		})
		(fetchurl {
			url = "https://registrationcenter-download.intel.com/akdlm/IRC_NAS/1ff1b38a-8218-4c53-9956-f0b264de35a4/l_HPCKit_p_2023.1.0.46346_offline.sh";
			sha256 = "0wfya02lljq4iid0nc5sn4055dkvgxwrc40x7qbgpdprzqx4a8l8";
		})
	];
	basekit = "${builtins.elemAt src 0}";
	hpckit = "${builtins.elemAt src 1}";

	nativeBuildInputs = [ autoPatchelfHook ];
	propagatedBuildInputs = [ ncurses stdenv.cc.cc.lib xorg.libXau ];

	# propagatedBuildInputs =
	# [
	# 	glibc glib libnotify xdg-utils ncurses nss 
	# 	at-spi2-core libxcb libdrm gtk3 mesa qt515.full 
	# 	zlib freetype fontconfig xorg.xorgproto xorg.libX11 xorg.libXt
	# 	xorg.libXft xorg.libXext xorg.libSM xorg.libICE
	# ];

	# libPath = lib.makeLibraryPath
	# [
	# 	stdenv.cc.cc libX11 glib libnotify xdg-utils 
	# 	ncurses nss at-spi2-core libxcb libdrm gtk3 
	# 	mesa qt515.full zlib atk nspr dbus pango cairo 
	# 	gdk-pixbuf cups expat libxkbcommon alsaLib
	# 	at-spi2-atk xorg.libXcomposite xorg.libxshmfence 
	# 	xorg.libXdamage xorg.libXext xorg.libXfixes
	# 	xorg.libXrandr
	# ];

	unpackPhase =
		let
			unpack = toolkit: "bash ${toolkit} --extract-only --extract-folder $TMP";
		in
		"
			${unpack basekit}
			${unpack hpckit}
		";
	patchPhase =
		"
			patchShebangs $TMP
			autoPatchelf $TMP
		";
	installPhase =
		let
			install = toolkit:
			"
				export HOME=$TMP
				toolkit_name=$(basename ${toolkit} | sed -e 's/\.sh//g' | sed -e 's/.*-//g')
				$TMP/\${toolkit_name}/install.sh --install-dir $out --eula accept -s
			";
		in
		"
			runHook preInstall
			${install basekit}
			${install hpckit}
			runHook postInstall
		";
}