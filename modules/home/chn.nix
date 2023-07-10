inputs:
{
	config =
	{
		home-manager.users.chn = { pkgs, ... }:
		{
			home.stateVersion = "22.11";
			programs.zsh = import ./zsh.nix { inherit pkgs; };
			programs.direnv.enable = true;
			programs.direnv.nix-direnv.enable = true;
		};
	};
}
