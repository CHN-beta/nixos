{ pkgs, ... }@inputs:
{
	options.nixos.kernel = let inherit (inputs.lib) mkOption types; in
	{
		cpu = mkOption { type = types.listOf (types.enum [ "intel" "amd" ]); default = []; };
	};
	config =
	{
		boot =
		{
			kernelParams = [ "delayacct" "acpi_osi=Linux" ];
			kernelPackages = inputs.pkgs.linuxPackages_xanmod_latest;
		};
		hardware.cpu = builtins.listToAttrs (builtins.map
			(name: { inherit name; value = { updateMicrocode = true; }; })
			inputs.config.nixos.kernel.cpu);
	};
}
