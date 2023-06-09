{ pkgs, ... }@inputs:
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
		]
		++ (with inputs.lib; filter isDerivation (attrValues pkgs.plasma5Packages.kdeGear));
		programs.wireshark.enable = true;
		nixpkgs.config.permittedInsecurePackages =
			[ "openssl-1.1.1u" "electron-19.0.7" "nodejs-14.21.3" "electron-13.6.9" ];
}
