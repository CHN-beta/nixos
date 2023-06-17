{ pkgs, ... }@inputs:
{
	config =
	{
		environment.systemPackages = with inputs.pkgs;
		[
			beep neofetch screen dos2unix tldr gnugrep pv
			pciutils usbutils lshw powertop compsize
			ksh
			vim nano
			wget aria2 curl yt-dlp
			tree git autojump exa
			nix-output-monitor inputs.inputs.nix-alien.packages.x86_64-linux.nix-alien
			apacheHttpd certbot-full
			pigz rar unrar upx unzip zip lzip
			util-linux snapper
			ocrmypdf pdfgrep
			openssl ssh-to-age gnupg age sops
			ipset iptables iproute2 dig nettools
			gcc clang-tools
			android-tools
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
				};
			};
		};
	};
}
