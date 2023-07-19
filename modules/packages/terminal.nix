inputs:
{
	config =
	{
		environment.systemPackages = with inputs.pkgs;
		[
			beep neofetch screen dos2unix tldr gnugrep pv
			pciutils usbutils lshw powertop compsize iotop iftop smartmontools htop intel-gpu-tools btop wayland-utils clinfo
			glxinfo vulkan-tools
			ksh
			vim nano
			wget aria2 curl yt-dlp
			tree git autojump exa
			nix-output-monitor inputs.topInputs.nix-alien.packages.x86_64-linux.nix-alien nix-template
			apacheHttpd certbot-full
			pigz rar unrar upx unzip zip lzip
			util-linux snapper
			ocrmypdf pdfgrep
			openssl ssh-to-age gnupg age sops
			ipset iptables iproute2 dig nettools
			gcc clang-tools
			sshfs kio-fuse
			pam_u2f
			e2fsprogs
			trash-cli tmux adb-sync pdfchain wgetpaste httplib clang magic-enum xtensor
			go rustc boost cereal cxxopts valgrind
			lsd zellij broot
			nil nixd
			p7zip appimage-run file
		];
		programs =
		{
			nix-index-database.comma.enable = true;
			nix-index.enable = true;
			command-not-found.enable = false;
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
			adb.enable = true;
			gnupg.agent =
			{
				enable = true;
				enableSSHSupport = true;
			};
		};
		services =
		{
			fwupd.enable = true;
			udev.packages = [ inputs.pkgs.yubikey-personalization ];
		};
	};
}
