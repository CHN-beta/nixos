inputs:
{
	config =
	{
		environment.systemPackages = with inputs.pkgs;
		[
			# thunder
			gparted snapper-gui
			google-chrome
			zotero texlive.combined.scheme-full
			
			# jail
			qq nur-xddxdd.wechat-uos inputs.config.nur.repos.linyinfeng.wemeet
			# nur-xddxdd.wine-wechat
			nur-xddxdd.baidupcs-go
			remmina
			bitwarden
			spotify yesplaymusic
			crow-translate
			scrcpy
			mpv nur-xddxdd.svp
			jetbrains.clion android-studio
			localPackages.typora
			yubikey-manager yubikey-manager-qt yubikey-personalization yubikey-personalization-gui
			appflowy
			nomacs
			putty virt-viewer
			wl-clipboard-x11 parallel lsof duperemove mlocate kmscon hdparm bat gnuplot whois zoom traceroute tcping-go
			tcpdump nmap mtr-gui simplescreenrecorder obs-studio 
			signal-desktop dbeaver ftxui yaml-cpp wl-mirror poppler_utils imagemagick gimp
			bottles # davinci-resolve playonlinux
			notion-app-enhanced appflowy joplin-desktop standardnotes
		]
		++ (with inputs.lib; filter isDerivation (attrValues inputs.pkgs.plasma5Packages.kdeGear));
		programs.wireshark = { enable = true; package = inputs.pkgs.wireshark; };
		nixpkgs.config = { permittedInsecurePackages = [ "openssl-1.1.1u" "electron-19.0.7" ]; allowUnfree = true; };
		programs.firefox = { enable = true; languagePacks = [ "zh-CN" "en-US" ]; };
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
	};
}
