{ hostname }:
{
	config =
	{
		nixpkgs.hostPlatform = "x86_64-linux";
		nix.settings.experimental-features = [ "nix-command" "flakes" ];
		networking.hostName = hostname;
		time.timeZone = "Asia/Shanghai";
		system.stateVersion = "22.11";
		nixpkgs.config.allowUnfree = true;
	};
}
