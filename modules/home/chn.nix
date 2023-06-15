{ pkgs, ... }@inputs:
{
	config =
	{
		home-manager.users.chn = { pkgs, ... }:
		{
			imports = [ inputs.inputs.plasma-manager.homeManagerModules.plasma-manager ];
			home.stateVersion = "22.11";
			programs.zsh = import ./zsh.nix { inherit pkgs; };
		};

	};
}
