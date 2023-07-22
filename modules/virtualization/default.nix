inputs:
{
	options.nixos.virtualization = let inherit (inputs.lib) mkOption types; in
	{
		waydroid.enable = mkOption { default = false; type = types.bool; };
		docker.enable = mkOption { default = false; type = types.bool; };
	};
	config = let inherit (inputs.lib) mkMerge mkIf; in mkMerge
	[
		# waydroid
		(mkIf inputs.config.nixos.virtualization.waydroid.enable { virtualisation = { waydroid.enable = true; }; })
		# docker
		(
			mkIf inputs.config.nixos.virtualization.docker.enable { virtualisation.docker =
				{
					enable = true;
					rootless = { enable = true; setSocketVariable = true; };
					enableNvidia = true;
					storageDriver = "overlay2";
				}; }
		)
	];
}

# sudo waydroid shell wm set-fix-to-user-rotation enabled
