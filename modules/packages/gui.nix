inputs:
{
	config =
	{
		environment.systemPackages = with inputs.pkgs;
		[
			( vscode-with-extensions.override
			{
				vscodeExtensions = (with vscode-extensions;
				[
					ms-vscode.cpptools
					genieai.chatgpt-vscode
					ms-ceintl.vscode-language-pack-zh-hans
					llvm-vs-code-extensions.vscode-clangd
					twxs.cmake
					ms-vscode.cmake-tools
					donjayamanne.githistory
					github.copilot
					github.github-vscode-theme
					ms-vscode.hexeditor
					oderwat.indent-rainbow
					ms-toolsai.jupyter
					ms-toolsai.vscode-jupyter-cell-tags
					ms-toolsai.jupyter-keymap
					ms-toolsai.jupyter-renderers
					ms-toolsai.vscode-jupyter-slideshow
					james-yu.latex-workshop
					yzhang.markdown-all-in-one
					pkief.material-icon-theme
					equinusocio.vsc-material-theme
					bbenoist.nix
					ms-python.vscode-pylance
					ms-python.python
					ms-vscode-remote.remote-ssh
					redhat.vscode-xml
					dotjoshjohnson.xml
				])
				++ (with nix-vscode-extensions.vscode-marketplace;
				[
					jeff-hykin.better-cpp-syntax
					ms-vscode.cpptools-extension-pack
					ms-vscode.cpptools-themes
					josetr.cmake-language-support-vscode
					fredericbonnet.cmake-test-adapter
					equinusocio.vsc-community-material-theme
					guyutongxue.cpp-reference
					intellsmi.comment-translate
					intellsmi.deepl-translate
					ms-vscode-remote.remote-containers
					fabiospampinato.vscode-diff
					cschlosser.doxdocgen
					znck.grammarly
					ms-python.isort
					thfriedrich.lammps
					leetcode.vscode-leetcode
					equinusocio.vsc-material-theme-icons
					gimly81.matlab
					affenwiesel.matlab-formatter
					xdebug.php-debug
					ckolkman.vscode-postgres
					ms-ossdata.vscode-postgresql
					ms-vscode-remote.remote-ssh-edit
					ms-vscode.remote-explorer
					ms-vscode.test-adapter-converter
					hbenl.vscode-test-explorer
					hirse.vscode-ungit
				]);
			} )
			qbittorrent # tunder
			gparted snapper-gui
			firefox google-chrome
			zotero texlive.combined.scheme-full libreoffice-qt
			element-desktop tdesktop discord
			# jail
			qq inputs.config.nur.repos.xddxdd.wechat-uos inputs.config.nur.repos.linyinfeng.wemeet
			remmina
			bitwarden
			spotify yesplaymusic
			crow-translate
			scrcpy
			mpv inputs.config.nur.repos.xddxdd.svp
			jetbrains.clion android-studio
			localPackages.typora
			yubikey-manager yubikey-manager-qt yubikey-personalization yubikey-personalization-gui
			appflowy
			nomacs
			putty virt-viewer
			wl-clipboard-x11 parallel lsof duperemove mlocate kmscon hdparm bat gnuplot whois zoom traceroute tcping-go
			tcpdump nmap mtr-gui simplescreenrecorder obs-studio 
			signal-desktop
		]
		++ (with inputs.lib; filter isDerivation (attrValues inputs.pkgs.plasma5Packages.kdeGear));
		programs.wireshark = { enable = true; package = inputs.pkgs.wireshark; };
		nixpkgs.config = { permittedInsecurePackages = [ "openssl-1.1.1u" "electron-19.0.7" ]; allowUnfree = true; };
		programs.firejail =
		{
			enable = true;
			wrappedBinaries =
			{
				qq =
				{
					executable = "${inputs.pkgs.qq}/bin/qq";
					profile = "${inputs.pkgs.firejail}/etc/firejail/linuxqq.profile";
				};
			};
		};
	};
}
