# Behaviors of these two NixOS modules would be different:
# { pkgs, ... }@inputs: { environment.systemPackages = [ pkgs.hello ]; }
# inputs: { environment.systemPackages = [ pkgs.hello ]; }
# The second one would failed to evaluate because nixpkgs would not pass pkgs to it.
# So that we wrote a wrapper to make it always works like the first one.
# Input a list of modules, allowed types are:
#	* attribute set
#	* file containing attribute set
#	* file containing lambda, which takes inputs as argument
#	* lambda, which takes inputs as argument
#	* list, first member is a lambda, 
moduleList: { pkgs, ... }@inputs:
{
	imports = builtins.map
	(
		let
			handle = { module, customArgs }:
				if ( builtins.typeOf module ) == "list"
					then handle { module = builtins.elemAt module 0; customArgs = builtins.elemAt module 1; }
				else if ( builtins.typeOf module ) == "path"
					then handle { module = import module; inherit customArgs; }
				else if ( builtins.typeOf module ) == "lambda" && customArgs != null # deprecated
					then handle { module = module customArgs; customArgs = null; }
				else if ( builtins.typeOf module ) == "lambda" then module inputs # deprecated
				else module;
			caller = module: handle { inherit module; customArgs = null; };
		in caller
	) moduleList;
}
