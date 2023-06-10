{ pkgs, ... }@inputs:
{
	config =
	{
		environment.systemPackages = with inputs.pkgs;
		[
			beep neofetch screen dos2unix tldr gnugrep
			pciutils usbutils lshw powertop
			ksh
			vim nano
			wget aria2 curl yt-dlp
			tree git autojump exa
			nix-output-monitor
			apacheHttpd certbot-full
			pigz rar unrar upx unzip zip
			util-linux snapper
			ocrmypdf pdfgrep
			openssl ssh-to-age gnupg age sops
			ipset iptables iproute2 dig nettools
			gcc clang-tools
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
