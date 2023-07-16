{
	lib, stdenv, fetchurl,
	glibc, zlib, file
  # glibc, libX11, glib, libnotify, xdg-utils, ncurses, nss, 
	# at-spi2-core, libxcb, libdrm, gtk3, mesa, qt515, zlib, xorg, atk, nspr, dbus,
	# pango, cairo, gdk-pixbuf, cups, expat, libxkbcommon, alsaLib, file, at-spi2-atk,
	# freetype, fontconfig
}:
	
stdenv.mkDerivation rec
{
	version = "2023.1";
	pname = "oneapi";

	sourceRoot = ".";
	srcs = [
		(fetchurl {
			url = "https://registrationcenter-download.intel.com/akdlm/IRC_NAS/7deeaac4-f605-4bcf-a81b-ea7531577c61/l_BaseKit_p_2023.1.0.46401_offline.sh";
			sha256 = "0cn32zqfbjv0vq43g6ap10crnsyk7nldyqpyyzn6g52j5h45g93l";
		})
		(fetchurl {
			url = "https://registrationcenter-download.intel.com/akdlm/IRC_NAS/1ff1b38a-8218-4c53-9956-f0b264de35a4/l_HPCKit_p_2023.1.0.46346_offline.sh";
			sha256 = "0wfya02lljq4iid0nc5sn4055dkvgxwrc40x7qbgpdprzqx4a8l8";
		})
	];

	nativeBuildInputs = [ file ];

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

	phases = [ "installPhase" "fixupPhase" "installCheckPhase" "distPhase" ];

	installPhase =
	''
		cd $sourceRoot
		mkdir -p $out/tmp
		base_kit=$(echo $srcs|cut -d" " -f1)
		hpc_kit=$(echo $srcs|cut -d" " -f2)
		# Extract files
		bash $base_kit --log $out/basekit_install_log --extract-only --extract-folder $out/tmp -a --install-dir $out \
			--download-cache $out/tmp --download-dir $out/tmp --log-dir $out/tmp -s --eula accept
		bash $hpc_kit --log $out/hpckit_install_log --extract-only --extract-folder $out/tmp -a --install-dir $out \
			--download-cache $out/tmp --download-dir $out/tmp --log-dir $out/tmp -s --eula accept
		for file in `grep -l -r "/bin/sh" $out/tmp`
		do
			sed -e "s,/bin/sh,${stdenv.shell},g" -i $file
		done
		export HOME=$out
		# Patch the bootstraper binaries and libs
		for files in `find $out/tmp/l_BaseKit_p_${version}_offline/lib`
		do
			patchelf --set-rpath "${glibc}/lib:$libPath:$out/tmp/l_BaseKit_p_${version}_offline/lib" $file 2>/dev/null || true
		done
		patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" --set-rpath "${glibc}/lib:$libPath:$out/tmp/l_BaseKit_p_${version}_offline/lib" $out/tmp/l_BaseKit_p_${version}_offline/bootstrapper
		# launch install
		export LD_LIBRARY_PATH=${zlib}/lib
		$out/tmp/l_BaseKit_p_${version}_offline/install.sh --install-dir $out --download-cache $out/tmp \
			--download-dir $out/tmp --log-dir $out/tmp --eula accept -s --ignore-errors
		$out/tmp/l_HPCKit_p_${version}_offline/install.sh --install-dir $out --download-cache $out/tmp --download-dir $out/tmp --log-dir $out/tmp --eula accept -s --ignore-errors
		rm -rf $out/tmp
	'';

	postFixup = ''
		echo "Fixing rights..."
		chmod u+w -R $out
		echo "Patching rpath and interpreter..."
		for dir in `find $out -mindepth 1 -maxdepth 1 -type d`
		do
			echo "	 $dir"
			for file in `find $dir -type f -exec file {} + | grep ELF| awk -F: '{print $1}'`
			do
					echo "			 $file"
					patchelf --set-interpreter "$(cat $NIX_CC/nix-support/dynamic-linker)" --set-rpath '$ORIGIN'":${glibc}/lib:$libPath:$dir/latest/lib64" $file 2>/dev/null || true
			done
		done
	'';

	meta = {
		description = "Intel OneAPI Basekit + HPCKit";
		maintainers = [ lib.maintainers.bzizou ];
		platforms = lib.platforms.linux;
		license = lib.licenses.unfree;
	};
}