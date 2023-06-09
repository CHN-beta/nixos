{ pkgs, ... }@inputs:
{
	config.environment.systemPackages = with inputs.pkgs;
	[
		beep neofetch screen dos2unix tldr gnugrep
		pciutils usbutils lshw powertop
		zsh ksh zsh-powerlevel10k zsh-autosuggestions zsh-syntax-highlighting 
		vim nano
		(
			vscode-with-extensions.override
			{
				vscodeExtensions = (with vscode-extensions;
				[
					ms-vscode.cpptools
					llvm-vs-code-extensions.vscode-clangd
					ms-vscode.cmake-tools
					ms-ceintl.vscode-language-pack-zh-hans
					github.copilot
					github.github-vscode-theme
					ms-vscode.hexeditor
					oderwat.indent-rainbow
					james-yu.latex-workshop
					pkief.material-icon-theme
					ms-vscode-remote.remote-ssh
				])
				++ (with nix-vscode-extensions.vscode-marketplace;
				[
					twxs.cmake
					ms-vscode.cpptools-themes
					guyutongxue.cpp-reference
				]);
			}
		)
		(
			pkgs.writeShellScriptBin "nvidia-offload"
			''
				export __NV_PRIME_RENDER_OFFLOAD=1
				export __NV_PRIME_RENDER_OFFLOAD_PROVIDER=NVIDIA-G0
				export __GLX_VENDOR_LIBRARY_NAME=nvidia
				export __VK_LAYER_NV_optimus=NVIDIA_only
				exec "$@"
			''
		)
		wget aria2 curl yt-dlp qbittorrent
		tree git autojump exa
		nix-output-monitor comma
		docker docker-compose
		apacheHttpd certbot-full
		pigz rar unrar upx unzip zip
		util-linux snapper gparted snapper-gui
		firefox google-chrome
		qemu_full virt-manager
		zotero ocrmypdf pdfgrep texlive.combined.scheme-full libreoffice-qt
		ovito paraview gimp # vsim vesta
		(python3.withPackages (ps: with ps; [ phonopy ]))
		element-desktop tdesktop discord qq inputs.config.nur.repos.xddxdd.wechat-uos inputs.config.nur.repos.linyinfeng.wemeet
		remmina
		bitwarden openssl ssh-to-age gnupg age sops
		spotify yesplaymusic # netease-cloud-music-gtk inputs.config.nur.repos.eh5.netease-cloud-music
		crow-translate
		scrcpy
		ipset iptables iproute2 wireshark dig nettools
		touchix.v2ray-forwarder
		mathematica
		gcc cudaPackages.cudatoolkit clang-tools
		inputs.config.nur.repos.ataraxiasjel.proton-ge
		octave root
		libsForQt5.qtstyleplugin-kvantum
	]
	++ (with inputs.lib; filter isDerivation (attrValues pkgs.plasma5Packages.kdeGear));
	config.programs =
	{
		wireshark.enable = true;
		anime-game-launcher.enable = true;
		honkers-railway-launcher.enable = true;
		nix-index-database.comma.enable = true;
		nix-index.enable = true;
		command-not-found.enable = false;
		steam.enable = true;
	};
	config.nixpkgs.config.permittedInsecurePackages = [ "openssl-1.1.1u" "electron-19.0.7" ];
	config.nix.settings.substituters = [ "https://xddxdd.cachix.org" ];
	config.nix.settings.trusted-public-keys = [ "xddxdd.cachix.org-1:ay1HJyNDYmlSwj5NXQG065C8LfoqqKaTNCyzeixGjf8=" ];
}
