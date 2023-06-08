{ config, pkgs, lib, ... } @inputs:

{
	# 基本设置
	nix.settings.experimental-features = [ "nix-command" "flakes" ];
	networking.hostName = "chn-PC";
	networking.networkmanager.enable = true;
	time.timeZone = "Asia/Shanghai";
	i18n =
	{
		defaultLocale = "zh_CN.UTF-8";
		supportedLocales = ["zh_CN.UTF-8/UTF-8" "en_US.UTF-8/UTF-8" "C.UTF-8/UTF-8"];
	};
	system.stateVersion = "22.11";

	# 输入法
	i18n.inputMethod =
	{
		enabled = "fcitx5";
		fcitx5.addons = with pkgs; [fcitx5-rime fcitx5-chinese-addons fcitx5-mozc];
	};

	# 图形界面
	services.xserver =
	{
		enable = true;
		displayManager.sddm.enable = true;
		desktopManager.plasma5.enable = true;
		videoDrivers = [ "nvidia" "intel" "qxl" ];
	};
	hardware.nvidia.prime =
	{
		offload.enable = true;
		intelBusId = "PCI:0:2:0";
		nvidiaBusId = "PCI:1:0:0";
	};

	# 打印机
	services.printing.enable = true;

	# 声音
	sound.enable = true;
	hardware.pulseaudio.enable = false;
	security.rtkit.enable = true;
	services.pipewire =
	{
		enable = true;
		alsa.enable = true;
		alsa.support32Bit = true;
		pulse.enable = true;
	};

	# 虚拟机（作为顾客）
	services.qemuGuest.enable = true;
	services.spice-vdagentd.enable = true;

	# waydroid
	virtualisation.waydroid.enable = true;
	virtualisation.lxd.enable = true;

	# 用户
	users.users.chn =
	{
		isNormalUser = true;
		extraGroups = [ "networkmanager" "wheel" "wireshark" "libvirtd" ];
		passwordFile = config.sops.secrets."password/chn".path;
		shell = pkgs.zsh;
	};
	users.mutableUsers = false;
	sops.secrets."password/chn".neededForUsers = true;
	home-manager.useGlobalPkgs = true;
	home-manager.useUserPackages = true;
	home-manager.users.chn = { pkgs, ... }:
	{
		home.stateVersion = "22.11";
		programs.zsh =
		{
			enable = true;
			initExtraBeforeCompInit =
			''
				# p10k instant prompt
				P10K_INSTANT_PROMPT="$XDG_CACHE_HOME/p10k-instant-prompt-''${(%):-%n}.zsh"
				[[ ! -r "$P10K_INSTANT_PROMPT" ]] || source "$P10K_INSTANT_PROMPT"

				HYPHEN_INSENSITIVE="true"
			'';

			plugins =
			[
				{
					file = "powerlevel10k.zsh-theme";
					name = "powerlevel10k";
					src = "${pkgs.zsh-powerlevel10k}/share/zsh-powerlevel10k";
				}
				{
					file = "p10k.zsh";
					name = "powerlevel10k-config";
					src = ./p10k-config;
				}
				{
					name = "zsh-exa";
					src = pkgs.fetchFromGitHub
					{
						owner = "ptavares";
						repo = "zsh-exa";
						rev = "0.2.3";
						sha256 = "0vn3iv9d3c1a4rigq2xm52x8zjaxlza1pd90bw9mbbkl9iq8766r";
					};
				}
			];
		};
		# xsession.profileExtra =
		# ''
		# 	export GTK_USE_PORTAL="1"
		# '';

	};

	# 软件包
	environment.systemPackages = with pkgs;
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
		element-desktop tdesktop discord qq config.nur.repos.xddxdd.wechat-uos config.nur.repos.linyinfeng.wemeet
		remmina
		bitwarden openssl ssh-to-age gnupg age sops
		spotify yesplaymusic # netease-cloud-music-gtk config.nur.repos.eh5.netease-cloud-music
		crow-translate
		scrcpy
		ipset iptables iproute2 wireshark dig nettools
		touchix.v2ray-forwarder
		mathematica
		gcc cudaPackages.cudatoolkit clang-tools
		config.nur.repos.ataraxiasjel.proton-ge
		octave root
		libsForQt5.qtstyleplugin-kvantum
	]
	++ (with lib; filter isDerivation (attrValues pkgs.plasma5Packages.kdeGear));
	programs.wireshark.enable = true;
	programs.anime-game-launcher.enable = true;
	programs.honkers-railway-launcher.enable = true;
	programs.nix-index-database.comma.enable = true;
	programs.nix-index.enable = true;
	programs.command-not-found.enable = false;
	programs.steam.enable = true;
	nixpkgs.config.permittedInsecurePackages =
		[ "openssl-1.1.1u" "electron-19.0.7" "nodejs-14.21.3" "electron-13.6.9" ];
	nix.settings.substituters = [ "https://xddxdd.cachix.org" ];
	nix.settings.trusted-public-keys = [ "xddxdd.cachix.org-1:ay1HJyNDYmlSwj5NXQG065C8LfoqqKaTNCyzeixGjf8=" ];

	# 字体
	fonts =
	{
		fontDir.enable = true;
		fonts = with pkgs;
			[ noto-fonts source-han-sans source-han-serif source-code-pro hack-font jetbrains-mono nerdfonts ];
		fontconfig.defaultFonts =
		{
			emoji = [ "Noto Color Emoji" ];
			monospace = [ "Noto Sans Mono CJK SC" "Sarasa Mono SC" "DejaVu Sans Mono"];
			sansSerif = ["Noto Sans CJK SC" "Source Han Sans SC" "DejaVu Sans"];
			serif = ["Noto Serif CJK SC" "Source Han Serif SC" "DejaVu Serif"];
		};
	};

	# zsh
	programs.zsh =
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

	# ssh security?
	services.openssh.enable = true;

	# firewall
	# networking.firewall.allowedTCPPorts = [ ... ];
	# networking.firewall.allowedUDPPorts = [ ... ];

	# sops
	sops = { defaultSopsFile = ./secrets/chn-PC.yaml; age.sshKeyPaths = [ "/etc/ssh/ssh_host_ed25519_key" ]; };

	# 翻墙
	services.dnsmasq =
	{
		enable = true;
		settings = {
			no-poll = true;
			server = [ "127.0.0.1#10853" ];
			listen-address = "127.0.0.1";
			bind-interfaces = true;
			address = [
				"/mirism.one/216.24.188.24"
				"/beta.mirism.one/216.24.188.24"
				"/ng01.mirism.one/216.24.188.24"
				"/debug.mirism.one/127.0.0.1"
			];
			ipset = [
				"/developer.download.nvidia.com/noproxy_net"
				"/yuanshen.com/noproxy_net"
				"/zoom.us/noproxy_net"
			];	
		};
	};
	services.xray = { enable = true; settingsFile = config.sops.secrets."xray.json".path; };
	sops.secrets."xray.json" = { mode = "0440"; owner = "v2ray"; group = "v2ray"; restartUnits = [ "xray.service" ]; };
	systemd.services.xray.serviceConfig =
	{
		DynamicUser = lib.mkForce false;
		User = "v2ray";
		Group = "v2ray";
		CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
		AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
	};
	users.users.v2ray = { isSystemUser = true; group = "v2ray"; };
	users.groups.v2ray = {};
	services.v2ray-forwarder = { enable = true; proxyPort = 10880; xmuPort = 10881; };
	boot.kernel.sysctl =
	{
		"net.ipv4.conf.all.route_localnet" = true;
		"net.ipv4.conf.default.route_localnet" = true;
		"net.ipv4.conf.all.accept_local" = true;
		"net.ipv4.conf.default.accept_local" = true;
		"net.ipv4.ip_forward" = true;
		"net.ipv4.ip_nonlocal_bind" = true;
	};

	programs.firejail.enable = true;
	hardware.xone.enable = true;
	hardware.xpadneo.enable = true;
	hardware.bluetooth.enable = true;
	services.xserver.synaptics.enable = false;
	services.xserver.libinput.enable = true;
	virtualisation.libvirtd.enable = true;

	nixpkgs.config.packageOverrides = pkgs: rec {
		wpa_supplicant = pkgs.wpa_supplicant.overrideAttrs (attrs: {
			patches = attrs.patches ++ [ ./patches/xmunet.patch ];
		});
	};

	environment.sessionVariables."GTK_USE_PORTAL" = "1";
	xdg.portal.extraPortals = with pkgs; [ xdg-desktop-portal-gtk xdg-desktop-portal-wlr ];
	virtualisation.spiceUSBRedirection.enable = true;
	networking.resolvconf.enable = false;
	environment.etc."resolv.conf".text =
	''
		nameserver 127.0.0.1
	'';
	programs.xwayland.enable = true;
	hardware.tuxedo-control-center.enable = true;
	hardware.tuxedo-keyboard.enable = true;
	systemd.extraConfig = "DefaultTimeoutStopSec=10s";
	systemd.user.extraConfig = "DefaultTimeoutStopSec=10s";
	systemd.services.home-manager-chn.before = [ "display-manager.service" ];
	nix.extraOptions =
	''
		keep-outputs = true
	'';
	nix.settings.system-features = [ "gccarch-alderlake" ];
}
