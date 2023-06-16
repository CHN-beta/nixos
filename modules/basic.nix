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
			extraConfig = "DefaultTimeoutStopSec=10s";
			user.extraConfig = "DefaultTimeoutStopSec=10s";
			services.nix-daemon.serviceConfig = { Slice = "-.slice"; Nice = "19"; };
		};
		programs.nix-ld.enable = true;
		boot.supportedFilesystems = [ "ntfs" ];
	};
}
