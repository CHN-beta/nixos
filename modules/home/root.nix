{
	config.home-manager =
	{
		useGlobalPkgs = true;
		useUserPackages = true;
		users.root = { pkgs, ... }:
		{
			home.stateVersion = "22.11";
			programs.zsh = import ./zsh.nix { inherit pkgs; };
		};
	};
}
