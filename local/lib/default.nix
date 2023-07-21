lib:
{
	mkModules = import ./mkModules.nix;
	mkSystem = import ./mkSystems.nix;
	mkInputs = import ./mkInputs.nix;
	attrsToList = import ./attrsToList.nix;
}
