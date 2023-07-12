inputs:
{
	config.environment.systemPackages =
	(
		with inputs.pkgs;
		[
			ovito paraview localPackages.vesta # vsim
			(python3.withPackages (ps: with ps;
			[
				phonopy inquirerpy requests tqdm tensorflow keras python-telegram-bot
				localPackages.upho localPackages.spectral
			]))
			mathematica octave root cling gfortran
			qchem.quantum-espresso
			waifu2x-converter-cpp
		]
	)
	++ ( with inputs.pkgs.pkgsCross.mingwW64.buildPackages; [ gcc ] );
	config.programs.ccache.enable = true;
	config.nix.settings.extra-sandbox-paths = [ inputs.config.programs.ccache.cacheDir ];
	# programs.ccache.packageNames = [ "wxGTK32" ];
}

# cross-x86_64-pc-linux-musl/gcc
# dev-cpp/cpp-httplib ? how to use
# dev-cpp/cppcoro
# dev-cpp/date
# dev-cpp/nameof
# dev-cpp/scnlib
# dev-cpp/tgbot-cpp
# dev-libs/pocketfft
# dev-util/intel-hpckit
# dev-util/nvhpc
# kde-misc/wallpaper-engine-kde-plugin
# media-fonts/arphicfonts
# media-fonts/sarasa-gothic
# media-gfx/flameshot
# media-libs/libva-intel-driver
# media-libs/libva-intel-media-driver
# media-sound/netease-cloud-music
# net-vpn/frp
# net-wireless/bluez-tools
# sci-libs/mkl
# sci-libs/openblas
# sci-libs/pfft
# sci-libs/scalapack
# sci-libs/wannier90
# sci-mathematics/ginac
# sci-mathematics/mathematica
# sci-mathematics/octave
# sci-physics/lammps::touchfish-os
# sci-physics/vsim
# sci-visualization/scidavis
# sys-apps/flatpak
# sys-cluster/modules
# sys-devel/distcc
# sys-fs/btrfs-progs
# sys-fs/compsize
# sys-fs/dosfstools
# sys-fs/duperemove
# sys-fs/exfatprogs
# sys-fs/mdadm
# sys-fs/ntfs3g
# sys-kernel/dracut
# sys-kernel/linux-firmware
# sys-kernel/xanmod-sources
# sys-kernel/xanmod-sources:6.1.12
# sys-kernel/xanmod-sources::touchfish-os
# sys-libs/libbacktrace
# sys-libs/libselinux
# x11-apps/xinput
# x11-base/xorg-apps
# x11-base/xorg-fonts
# x11-base/xorg-server
# x11-misc/imwheel
# x11-misc/optimus-manager
# x11-misc/unclutter-xfixes

