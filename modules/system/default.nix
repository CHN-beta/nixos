inputs:
{
	options.nixos.system = let inherit (inputs.lib) mkOption types; in
	{
		hostname = mkOption { type = types.nonEmptyStr; };
		march = mkOption { type = types.nullOr types.nonEmptyStr; };
		type = mkOption { type = types.enum [ "headless" "desktop" "workstation" ]; default = "headless"; };
	};
	config = let inherit (inputs.lib) mkMerge mkIf; inherit (inputs.localLib) mkConditional stripeTabs; in mkMerge
	[
		# generic
		{
			nix =
			{
				settings =
				{
					system-features = [ "big-parallel" "nixos-test" "benchmark" ];
					experimental-features = [ "nix-command" "flakes" ];
					keep-outputs = true;
					keep-failed = true;
					auto-optimise-store = true;
				};
				daemonIOSchedClass = "idle";
				daemonCPUSchedPolicy = "idle";
				registry =
				{
					nixpkgs.flake = inputs.topInputs.nixpkgs;
					nixos-config.flake = inputs.topInputs.self;
				};
			};
			services =
			{
				udev.extraRules = stripeTabs
				''
					ACTION=="add|change", KERNEL=="[sv]d[a-z]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="bfq"
					ACTION=="add|change", KERNEL=="nvme[0-9]n[0-9]", ATTR{queue/rotational}=="0", ATTR{queue/scheduler}="bfq"
				'';
				dbus.implementation = "broker";
			};
			networking.networkmanager.enable = true;
			programs = { dconf.enable = true; nix-ld.enable = true; };
			nixpkgs.config.allowUnfree = true;
			time.timeZone = "Asia/Shanghai";
			system =
			{
				stateVersion = "22.11";
				configurationRevision = inputs.topInputs.self.rev or "dirty";
			};
			boot =
			{
				kernel.sysctl =
				{
					"net.core.rmem_max" = 67108864;
					"net.core.wmem_max" = 67108864;
					"net.ipv4.tcp_rmem" = "4096 87380 67108864";
					"net.ipv4.tcp_wmem" = "4096 65536 67108864";
					"net.ipv4.tcp_mtu_probing" = true;
					"net.ipv4.tcp_tw_reuse" = true;
					"vm.swappiness" = 10;
					"net.ipv4.tcp_max_syn_backlog" = 8388608;
					"net.core.netdev_max_backlog" = 8388608;
					"net.core.somaxconn" = 8388608;
					"vm.oom_kill_allocating_task" = true;
					"vm.oom_dump_tasks" = false;
					"vm.overcommit_memory" = 1;
					"dev.i915.perf_stream_paranoid" = false;
				};
				supportedFilesystems = [ "ntfs" ];
				consoleLogLevel = 7;
			};
			hardware.enableAllFirmware = true;
			systemd =
			{
				extraConfig = stripeTabs
				"
					DefaultTimeoutStopSec=10s
					DefaultLimitNOFILE=1048576:1048576
				";
				user.extraConfig = "DefaultTimeoutStopSec=10s";
				services =
				{
					nix-daemon =
					{
						serviceConfig = { CacheDirectory = "nix"; Slice = "-.slice"; Nice = "19"; };
						environment = { TMPDIR = "/var/cache/nix"; };
					};
					systemd-tmpfiles-setup = { environment = { SYSTEMD_TMPFILES_FORCE_SUBVOL = "0"; }; };
				};
				timers.systemd-tmpfiles-clean.enable = false;
			};
		}
		# hostname
		{ networking.hostName = inputs.config.nixos.system.hostname; }
		# march
		(
			mkConditional (inputs.config.nixos.system.march != null)
				{
					nixpkgs =
					{
						hostPlatform = { system = "x86_64-linux"; gcc =
							{ arch = inputs.config.nixos.system.march; tune = inputs.config.nixos.system.march; }; };
						config.qchem-config.optArch = inputs.config.nixos.system.march;
					};
					nix.settings.system-features = [ "gccarch-${inputs.config.nixos.system.march}" ];
					boot.kernelPatches =
					[{
						name = "native kernel";
						patch = null;
						extraStructuredConfig =
						{
							GENERIC_CPU = inputs.lib.kernel.no;
							"M${inputs.lib.strings.toUpper inputs.config.nixos.system.march}" = inputs.lib.kernel.yes;
						};
					}];
				}
				{ nixpkgs.hostPlatform = inputs.lib.mkDefault "x86_64-linux"; }
		)
		# type
		(
			mkMerge
			[
				{
					environment.systemPackages = with inputs.pkgs;
					[
						# shell
						ksh
						# basic tools
						beep dos2unix gnugrep pv tmux
						# lsxx
						pciutils usbutils lshw wayland-utils clinfo glxinfo vulkan-tools util-linux
						# top
						iotop iftop htop
						# editor
						vim nano
						# downloader
						wget aria2 curl yt-dlp
						# file manager
						tree git autojump exa trash-cli lsd zellij broot file
						# compress
						pigz rar upx unzip zip lzip p7zip
						# file system management
						sshfs e2fsprogs adb-sync
						# disk management
						smartmontools
						# encryption and authentication
						apacheHttpd openssl ssh-to-age gnupg age sops
						# networking
						ipset iptables iproute2 dig nettools
						# nix tools
						nix-output-monitor nix-template appimage-run nil nixd nix-alien
						# development
						gcc go rustc

						# move to other place
						kio-fuse pam_u2f tldr
						pdfchain wgetpaste httplib clang magic-enum xtensor
						boost cereal cxxopts valgrind
						todo-txt-cli pandoc
						# nix-ld
					];
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
						command-not-found.enable = false;
						adb.enable = true;
						gnupg.agent = { enable = true; enableSSHSupport = true; };
					};
					services =
					{
						fwupd.enable = true;
						udev.packages = [ inputs.pkgs.yubikey-personalization ];
					};
				}
			]
		)
	];
}
