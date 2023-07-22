inputs:
{
	config =
	{
		nix =
		{
			settings =
			{
				experimental-features = [ "nix-command" "flakes" ];
				keep-outputs = true;
				system-features = [ "big-parallel" ];
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
			# nixPath =
			# [
			# 	"nixpkgs=/etc/channels/nixpkgs"
			# 	"nixos-config=/etc/nixos/configuration.nix"
			# 	"/nix/var/nix/profiles/per-user/root/channels"
			# ];
		};
		time.timeZone = "Asia/Shanghai";
		system =
		{
			stateVersion = "22.11";
			configurationRevision = inputs.topInputs.self.rev or "dirty";
		};
		nixpkgs.config.allowUnfree = true;
		systemd =
		{
			extraConfig =
			"
				DefaultTimeoutStopSec=10s
				DefaultLimitNOFILE=1048576:1048576
			";
			user.extraConfig = "DefaultTimeoutStopSec=10s";
			sleep.extraConfig =
			"
				SuspendState=freeze
				HibernateMode=shutdown
			";
			services.nix-daemon.serviceConfig = { Slice = "-.slice"; Nice = "19"; };
			timers.systemd-tmpfiles-clean.enable = false;
		};
		programs.nix-ld.enable = true;
		boot = { supportedFilesystems = [ "ntfs" ]; consoleLogLevel = 7; };
		hardware.enableAllFirmware = true;
		security.pam =
		{
			u2f = { enable = true; cue = true; authFile = ./u2f_keys; };
			services = builtins.listToAttrs (builtins.map (name: { inherit name; value = { u2fAuth = true; }; })
				[ "login" "sudo" "su" "kde" "polkit-1" ]);
		};
		systemd.nspawn =
			let
				f = name: { inherit name; value =
				{
					execConfig.PrivateUsers = false;
					networkConfig.VirtualEthernet = false;
				}; };
			in
				builtins.listToAttrs (builtins.map f [ "arch" "ubuntu-22.04" ]);
		environment.etc."channels/nixpkgs".source = inputs.topInputs.nixpkgs.outPath;
		# environment.pathsToLink = [ "/include" ];
		# environment.variables.CPATH = "/run/current-system/sw/include";
		# environment.variables.LIBRARY_PATH = "/run/current-system/sw/lib";
	};
}
