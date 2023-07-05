inputs:
{
	config.environment.systemPackages =
	(
		with inputs.pkgs;
		[
			ovito paraview localPackages.vesta # vsim
			(python3.withPackages (ps: with ps;
			[
				phonopy inquirerpy requests tqdm tensorflow keras
				localPackages.upho localPackages.spectral
			]))
			mathematica octave root cling gfortran
			qchem.quantum-espresso
		]
	)
	++ ( with inputs.pkgs.pkgsCross.mingwW64.buildPackages; [ gcc ] );

}

# cross-x86_64-pc-linux-musl/gcc
# dev-cpp/cpp-httplib ? how to use
# dev-cpp/cppcoro
# dev-cpp/date
# dev-cpp/ftxui
# dev-cpp/magic-enum
# dev-cpp/nameof
# dev-cpp/scnlib
# dev-cpp/tgbot-cpp
# dev-cpp/xtensor
# dev-cpp/yaml-cpp
# dev-lang/go
# dev-lang/rust-bin
# dev-libs/boost
# dev-libs/cereal
# dev-libs/cxxopts
# dev-libs/pocketfft
# dev-python/phonopy
# dev-python/pip
# dev-python/python-telegram-bot
# dev-util/android-sdk-update-manager
# dev-util/android-studio
# dev-util/android-tools
# dev-util/ccache
# dev-util/clion
# dev-util/intel-hpckit
# dev-util/kdevelop
# dev-util/nvhpc
# dev-util/nvidia-cuda-toolkit
# dev-util/valgrind
# dev-vcs/git
# games-misc/an-anime-game-launcher
# games-util/steam-games-meta
# games-util/steam-meta
# games-util/xpadneo
# kde-apps/ark
# kde-apps/dolphin
# kde-apps/filelight
# kde-apps/kde-apps-meta
# kde-apps/kdenlive
# kde-apps/konsole
# kde-apps/kwalletmanager
# kde-apps/okular
# kde-apps/yakuake
# kde-misc/kdeconnect
# kde-misc/wallpaper-engine-kde-plugin
# kde-plasma/ksysguard
# kde-plasma/plasma-meta
# mail-client/mailspring-bin
# mail-client/thunderbird
# media-fonts/arphicfonts
# media-fonts/fonts-meta
# media-fonts/nerd-fonts
# media-fonts/noto-cjk
# media-fonts/sarasa-gothic
# media-gfx/flameshot
# media-gfx/gimp
# media-gfx/nomacs
# media-gfx/waifu2x-ncnn-vulkan
# media-libs/libva-intel-driver
# media-libs/libva-intel-media-driver
# media-sound/netease-cloud-music
# net-p2p/qbittorrent
# net-proxy/Xray::touchfish-os
# net-proxy/v2ray::touchfish-os
# net-vpn/frp
# net-wireless/aircrack-ng
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
# sys-apps/hdparm
# sys-apps/kmscon
# sys-apps/lshw
# sys-apps/mlocate
# sys-cluster/modules
# sys-devel/clang
# sys-devel/crossdev
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
# sys-power/powertop
# sys-power/tlpui
# sys-process/btop
# sys-process/htop
# sys-process/iotop
# sys-process/lsof
# sys-process/parallel
# www-client/firefox
# x11-apps/xinput
# x11-base/xorg-apps
# x11-base/xorg-fonts
# x11-base/xorg-server
# x11-misc/imwheel
# x11-misc/optimus-manager
# x11-misc/unclutter-xfixes

