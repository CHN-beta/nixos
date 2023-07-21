lib:
{
	attrsToList = import ./attrsToList.nix;
	mkConditional = import ./mkConditional.nix lib;
	mkModules = import ./mkModules.nix;
	stripeTabs = import ./stripeTabs.nix;
}
