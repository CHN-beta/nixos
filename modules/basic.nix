{ hostName }: { pkgs, ... }@inputs:
{
	config =
	{
		nixpkgs.hostPlatform = "x86_64-linux";
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
		};
		networking.hostName = hostName;
		time.timeZone = "Asia/Shanghai";
		system.stateVersion = "22.11";
		nixpkgs.config.allowUnfree = true;
		systemd =
		{
			extraConfig =
			"
				DefaultTimeoutStopSec=10s
				DefaultLimitNOFILE=1048576:1048576
			";
			user.extraConfig = "DefaultTimeoutStopSec=10s";
			sleep.extraConfig = "SuspendState=freeze";
			services.nix-daemon.serviceConfig = { Slice = "-.slice"; Nice = "19"; };
		};
		programs.nix-ld.enable = true;
		boot = { supportedFilesystems = [ "ntfs" ]; consoleLogLevel = 7; };
	};
}
