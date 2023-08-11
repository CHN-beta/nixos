inputs:
{
	options.nixos.packages = let inherit (inputs.lib) mkOption types; in
	{
		packageSet = mkOption
		{
			type = types.enum
			[
				# no gui, only used for specific purpose
				"server"
				# gui, for daily use, but not install large programs such as matlab
				"desktop"
				# nearly everything
				"workstation"
			];
			default = "server";
		};
		extraPackages = mkOption { type = types.listOf types.unspecified; default = []; };
		excludePackages = mkOption { type = types.listOf types.unspecified; default = []; };
		extraPythonPackages = mkOption { type = types.listOf types.unspecified; default = []; };
		excludePythonPackages = mkOption { type = types.listOf types.unspecified; default = []; };
		extraPrebuildPackages = mkOption { type = types.listOf types.unspecified; default = []; };
		excludePrebuildPackages = mkOption { type = types.listOf types.unspecified; default = []; };
		_packages = mkOption { type = types.listOf types.unspecified; default = []; };
		_pythonPackages = mkOption { type = types.listOf types.unspecified; default = []; };
		_prebuildPackages = mkOption { type = types.listOf types.unspecified; default = []; };
	};
	config = let inherit (inputs.lib) mkMerge mkIf; inherit (inputs.localLib) stripeTabs; in mkMerge
	[
		# >= server
		{
			nixos.packages = with inputs.pkgs;
			{
				_packages = 
				[
					# shell
					ksh
					# basic tools
					beep dos2unix gnugrep pv tmux screen parallel tldr cowsay jq
					# lsxx
					pciutils usbutils lshw util-linux lsof
					# top
					iotop iftop htop btop powertop s-tui
					# editor
					vim nano bat
					# downloader
					wget aria2 curl
					# file manager
					tree git exa trash-cli lsd zellij broot file xdg-ninja mlocate
					# compress
					pigz rar upx unzip zip lzip p7zip
					# file system management
					sshfs e2fsprogs adb-sync duperemove compsize
					# disk management
					smartmontools hdparm
					# encryption and authentication
					apacheHttpd openssl ssh-to-age gnupg age sops pam_u2f
					# networking
					ipset iptables iproute2 dig nettools traceroute tcping-go whois tcpdump nmap
					# nix tools
					nix-output-monitor
					# development
					clang-tools
					# office
					todo-txt-cli pandoc pdfchain
				] ++ (with inputs.config.boot.kernelPackages; [ cpupower usbip ]);
			};
			programs =
			{
				nix-index-database.comma.enable = true;
				nix-index.enable = true;
				zsh =
				{
					enable = true;
					syntaxHighlighting.enable = true;
					autosuggestions.enable = true;
					enableCompletion = true;
					ohMyZsh =
					{
						enable = true;
						plugins = [ "git" "colored-man-pages" "extract" "history-substring-search" "autojump" ];
						customPkgs = with inputs.pkgs; [ zsh-nix-shell ];
					};
				};
				ccache.enable = true;
				command-not-found.enable = false;
				adb.enable = true;
				gnupg.agent = { enable = true; enableSSHSupport = true; };
				autojump.enable = true;
			};
			services =
			{
				fwupd.enable = true;
				udev.packages = [ inputs.pkgs.yubikey-personalization ];
			};
			nix.settings.extra-sandbox-paths = [ inputs.config.programs.ccache.cacheDir ];
			nixpkgs.config =
			{
				permittedInsecurePackages = [ "openssl-1.1.1u" "electron-19.0.7" ];
				allowUnfree = true;
			};
		}
		# >= desktop
		(
			mkIf (builtins.elem inputs.config.nixos.packages.packageSet [ "desktop" "workstation" ] )
			{
				nixos.packages = with inputs.pkgs;
				{
					_packages =
					[
						# system management
						gparted snapper-gui libsForQt5.qtstyleplugin-kvantum wl-clipboard-x11 kio-fuse wl-mirror
						wayland-utils clinfo glxinfo vulkan-tools dracut
						# nix tools
						nix-template appimage-run nil nixd nix-alien ssh-to-age nix-serve
						# instant messager
						element-desktop telegram-desktop discord qq nur-xddxdd.wechat-uos # jail
						inputs.config.nur.repos.linyinfeng.wemeet # native # nur-xddxdd.wine-wechat thunder
						zoom-us signal-desktop cinny-desktop
						# browser
						google-chrome
						# networking
						remmina putty mtr-gui
						# password and key management
						bitwarden yubikey-manager yubikey-manager-qt yubikey-personalization yubikey-personalization-gui
						# download
						qbittorrent yt-dlp nur-xddxdd.baidupcs-go wgetpaste
						# office
						crow-translate libreoffice-qt zotero texlive.combined.scheme-full gnuplot poppler_utils pdftk
						# development
						scrcpy jetbrains.clion android-studio dbeaver cling
						# media
						nur-xddxdd.svp spotify yesplaymusic mpv nomacs simplescreenrecorder obs-studio imagemagick gimp
						netease-cloud-music-gtk waifu2x-converter-cpp inkscape blender
						# virtualization
						wine virt-viewer bottles # wine64
						# text editor
						localPackages.typora appflowy notion-app-enhanced joplin-desktop standardnotes
						# math, physics and chemistry
						octave root ovito paraview localPackages.vesta qchem.quantum-espresso # vsim
						# themes
						orchis-theme tela-circle-icon-theme plasma-overdose-kde-theme materia-kde-theme graphite-kde-theme
						arc-kde-theme materia-theme
						# news
						fluent-reader newsflash rssguard newsboat
						# davinci-resolve playonlinux
						(
							vscode-with-extensions.override
							{
								vscodeExtensions = with nix-vscode-extensions.vscode-marketplace;
									(with equinusocio; [ vsc-community-material-theme vsc-material-theme-icons ])
									++ (with github; [ copilot github-vscode-theme ])
									++ (with intellsmi; [ comment-translate deepl-translate ])
									++ (with ms-python; [ isort python vscode-pylance ])
									++ (with ms-toolsai;
									[
										jupyter jupyter-keymap jupyter-renderers vscode-jupyter-cell-tags vscode-jupyter-slideshow
									])
									++ (with ms-vscode;
									[
										cmake-tools cpptools cpptools-extension-pack cpptools-themes hexeditor remote-explorer
										test-adapter-converter
									])
									++ (with ms-vscode-remote; [ remote-ssh remote-containers remote-ssh-edit ])
									++ [
										donjayamanne.githistory genieai.chatgpt-vscode fabiospampinato.vscode-diff cschlosser.doxdocgen
										llvm-vs-code-extensions.vscode-clangd ms-ceintl.vscode-language-pack-zh-hans oderwat.indent-rainbow
										twxs.cmake guyutongxue.cpp-reference znck.grammarly thfriedrich.lammps leetcode.vscode-leetcode
										james-yu.latex-workshop gimly81.matlab affenwiesel.matlab-formatter ckolkman.vscode-postgres
										yzhang.markdown-all-in-one pkief.material-icon-theme bbenoist.nix ms-ossdata.vscode-postgresql
										redhat.vscode-xml dotjoshjohnson.xml jnoortheen.nix-ide xdebug.php-debug hbenl.vscode-test-explorer
										jeff-hykin.better-cpp-syntax fredericbonnet.cmake-test-adapter mesonbuild.mesonbuild
										hirse.vscode-ungit fortran-lang.linter-gfortran tboox.xmake-vscode
									];
							}
						)
					] ++ (with inputs.lib; filter isDerivation (attrValues plasma5Packages.kdeGear));
					_pythonPackages = [(pythonPackages: with pythonPackages;
					[
						phonopy inquirerpy requests tensorflow keras python-telegram-bot tqdm
						fastapi pypdf2 pandas openai matplotlib scipy plotly gunicorn scikit-learn redis jinja2
					])];
					_prebuildPackages = [ httplib magic-enum xtensor boost cereal cxxopts ftxui yaml-cpp gfortran ];
				};
				programs =
				{
					anime-game-launcher.enable = true;
					honkers-railway-launcher.enable = true;
					steam.enable = true;
					kdeconnect.enable = true;
					wireshark = { enable = true; package = inputs.pkgs.wireshark; };
					firefox = { enable = true; languagePacks = [ "zh-CN" "en-US" ]; };
					nix-ld.enable = true;
				};
				nixpkgs.config.packageOverrides = pkgs: 
				{
					telegram-desktop = pkgs.telegram-desktop.overrideAttrs (attrs:
					{
						patches = (if (attrs ? patches) then attrs.patches else []) ++ [ ./telegram.patch ];
					});
				};
				services.pcscd.enable = true;
			}
		)
		# >= workstation
		(
			mkIf (inputs.config.nixos.packages.packageSet == "workstation")
			{
				nixos.packages._packages = with inputs.pkgs; [ mathematica ];
			}
		)
		# apply package configs
		{
			environment.systemPackages = let inherit (inputs.lib.lists) subtractLists; in with inputs.config.nixos.packages;
				(subtractLists excludePackages (_packages ++ extraPackages))
				++ [
					(inputs.pkgs.python3.withPackages (pythonPackages:
						subtractLists
							(builtins.concatLists (builtins.map (packageFunction: packageFunction pythonPackages)
								excludePythonPackages))
							(builtins.concatLists (builtins.map (packageFunction: packageFunction pythonPackages)
								(_pythonPackages ++ extraPythonPackages)))))
					(inputs.pkgs.callPackage ({ stdenv }: stdenv.mkDerivation
					{
						name = "prebuild-packages";
						propagateBuildInputs = subtractLists excludePrebuildPackages (_prebuildPackages ++ extraPrebuildPackages);
						phases = [ "installPhase" ];
						installPhase = stripeTabs
						''
							runHook preInstall
							mkdir -p $out
							runHook postInstall
						'';
					}) {})
				];
		}
	];
}

		# programs.firejail =
		# {
		# 	enable = true;
		# 	wrappedBinaries =
		# 	{
		# 		qq =
		# 		{
		# 			executable = "${inputs.pkgs.qq}/bin/qq";
		# 			profile = "${inputs.pkgs.firejail}/etc/firejail/linuxqq.profile";
		# 		};
		# 	};
		# };

# config.nixpkgs.config.replaceStdenv = { pkgs }: pkgs.ccacheStdenv;
	# only replace stdenv for large and tested packages
	# config.programs.ccache.packageNames = [ "webkitgtk" "libreoffice" "tensorflow" "linux" "chromium" ];
	# config.nixpkgs.overlays = [(final: prev:
	# {
	# 	libreoffice-qt = prev.libreoffice-qt.override (prev: { unwrapped = prev.unwrapped.override
	# 		(prev: { stdenv = final.ccacheStdenv.override { stdenv = prev.stdenv; }; }); });
	# 	python3 = prev.python3.override { packageOverrides = python-final: python-prev:
	# 		{
	# 			tensorflow = python-prev.tensorflow.override
	# 				{ stdenv = final.ccacheStdenv.override { stdenv = python-prev.tensorflow.stdenv; }; };
	# 		};};
	# 	# webkitgtk = prev.webkitgtk.override (prev:
	# 	# 	{ stdenv = final.ccacheStdenv.override { stdenv = prev.stdenv; }; enableUnifiedBuilds = false; });
	# 	wxGTK31 = prev.wxGTK31.override { stdenv = final.ccacheStdenv.override { stdenv = prev.wxGTK31.stdenv; }; };
	# 	wxGTK32 = prev.wxGTK32.override { stdenv = final.ccacheStdenv.override { stdenv = prev.wxGTK32.stdenv; }; };
	# 	# firefox-unwrapped = prev.firefox-unwrapped.override
	# 	# 	{ stdenv = final.ccacheStdenv.override { stdenv = prev.firefox-unwrapped.stdenv; }; };
	# 	# chromium = prev.chromium.override
	# 	# 	{ stdenv = final.ccacheStdenv.override { stdenv = prev.chromium.stdenv; }; };
	# 	# linuxPackages_xanmod_latest = prev.linuxPackages_xanmod_latest.override
	# 	# {
	# 	# 	kernel = prev.linuxPackages_xanmod_latest.kernel.override
	# 	# 	{
	# 	# 		stdenv = final.ccacheStdenv.override { stdenv = prev.linuxPackages_xanmod_latest.kernel.stdenv; };
	# 	# 		buildPackages = prev.linuxPackages_xanmod_latest.kernel.buildPackages //
	# 	# 			{ stdenv = prev.linuxPackages_xanmod_latest.kernel.buildPackages.stdenv; };
	# 	# 	};
	# 	# };
	# })];
	# config.programs.ccache.packageNames = [ "libreoffice-unwrapped" ];

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

# 	++ ( with inputs.pkgs.pkgsCross.mingwW64.buildPackages; [ gcc ] );