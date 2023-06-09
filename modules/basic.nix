{ hostName }: { pkgs, ... }@inputs:
{
	config =
	{
		nixpkgs.hostPlatform = "x86_64-linux";
		nix.settings =
		{
			experimental-features = [ "nix-command" "flakes" ];
			keep-outputs = true;
			system-features = [ "big-parallel" ];
			keep-failed = true;
		};
		networking.hostName = hostName;
		time.timeZone = "Asia/Shanghai";
		system.stateVersion = "22.11";
		nixpkgs.config.allowUnfree = true;
		systemd = { extraConfig = "DefaultTimeoutStopSec=10s"; user.extraConfig = "DefaultTimeoutStopSec=10s"; };
	};
}
