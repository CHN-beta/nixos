inputs:
{
	options.nixos.system = let inherit (inputs.lib) mkOption types; in
	{
		hostname = mkOption { type = types.nonEmptyStr; };
		march = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
		gui.enable = mkOption { type = types.bool; default = false; };
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
			nixpkgs =
			{
				config.allowUnfree = true;
				overlays = [(final: prev: { genericPackages = (inputs.topInputs.nixpkgs.lib.nixosSystem
				{
					system = "x86_64-linux";
					modules = [{ config.nixpkgs.config.allowUnfree = true; }];
				}).pkgs;})];
			};
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
					"net.ipv4.conf.all.route_localnet" = true;
					"net.ipv4.conf.default.route_localnet" = true;
					"net.ipv4.conf.all.accept_local" = true;
					"net.ipv4.conf.default.accept_local" = true;
					"net.ipv4.ip_forward" = true;
					"net.ipv4.ip_nonlocal_bind" = true;
					"net.bridge.bridge-nf-call-iptables" = false;
					"net.bridge.bridge-nf-call-ip6tables" = false;
					"net.bridge.bridge-nf-call-arptables" = false;
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
			environment =
			{
				etc."channels/nixpkgs".source = inputs.topInputs.nixpkgs.outPath;
				etc."nixos".source = inputs.topInputs.self.outPath;
				sessionVariables =
				{
					XDG_CACHE_HOME = "$HOME/.cache";
					XDG_CONFIG_HOME = "$HOME/.config";
					XDG_DATA_HOME = "$HOME/.local/share";
					XDG_STATE_HOME = "$HOME/.local/state";
				};
			};
			i18n =
			{
				defaultLocale = "zh_CN.UTF-8";
				supportedLocales = ["zh_CN.UTF-8/UTF-8" "en_US.UTF-8/UTF-8" "C.UTF-8/UTF-8"];
			};
			# environment.pathsToLink = [ "/include" ];
			# environment.variables.CPATH = "/run/current-system/sw/include";
			# environment.variables.LIBRARY_PATH = "/run/current-system/sw/lib";
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
		# gui.enable
		(mkIf inputs.config.nixos.system.gui.enable
		{
				services.xserver =
				{
					enable = true;
					displayManager.sddm.enable = true;
					desktopManager.plasma5.enable = true;
					videoDrivers = inputs.config.nixos.hardware.gpus;
				};
				systemd.services.display-manager.after = [ "network-online.target" ];
				environment.sessionVariables."GTK_USE_PORTAL" = "1";
				xdg.portal.extraPortals = with inputs.pkgs; [ xdg-desktop-portal-gtk xdg-desktop-portal-wlr ];
				i18n.inputMethod =
				{
					enabled = "fcitx5";
					fcitx5.addons = with inputs.pkgs; [ fcitx5-rime fcitx5-chinese-addons fcitx5-mozc ];
				};
		})
	];
}
