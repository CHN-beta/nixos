# Behaviors of these two NixOS modules would be different:
# { pkgs, ... }@inputs: { environment.systemPackages = [ pkgs.hello ]; }
# inputs: { environment.systemPackages = [ pkgs.hello ]; }
# The second one would failed to evaluate because nixpkgs would not pass pkgs to it.
# So that we wrote a wrapper to make it always works like the first one.
moduleList: { pkgs, ... }@inputs:
{
	imports = builtins.map
		( module: if ( ( builtins.typeOf module ) == "set" ) then module else module inputs ) moduleList;
}
