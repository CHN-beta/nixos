lib:
{
	attrsToList = Attrs: builtins.map ( name: { inherit name; value = Attrs.${name}; } ) ( builtins.attrNames Attrs );
	mkConditional = condition: trueResult: falseResult: let inherit (lib) mkMerge mkIf; in
		mkMerge [ ( mkIf condition trueResult ) ( mkIf (!condition) falseResult ) ];

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
	mkModules = moduleList: { pkgs, ... }@inputs:
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
	};
	# Behaviors of these two NixOS modules would be different:
	# { pkgs, ... }@inputs: { environment.systemPackages = [ pkgs.hello ]; }
	# inputs: { environment.systemPackages = [ pkgs.hello ]; }
	# The second one would failed to evaluate because nixpkgs would not pass pkgs to it.
	# So that we wrote a wrapper to make it always works like the first one.
	# moduleList: { pkgs, ... }@inputs:
	# {
	# 	imports = builtins.map
	# 	(
	# 		handle = module:
	# 			if ( builtins.typeOf module ) == "path" then handle import module
	# 			else if ( builtins.typeOf module ) == "lambda" then module inputs
	# 			else module;
	# 	) moduleList;
	# }

	# from: https://github.com/NixOS/nix/issues/3759
	stripeTabs = text:
		let
			# Whether all lines start with a tab (or is empty)
			shouldStripTab = lines: builtins.all (line: (line == "") || (lib.strings.hasPrefix "	" line)) lines;
			# Strip a leading tab from all lines
			stripTab = lines: builtins.map (line: lib.strings.removePrefix "	" line) lines;
			# Strip tabs recursively until there are none
			stripTabs = lines: if (shouldStripTab lines) then (stripTabs (stripTab lines)) else lines;
		in
			# Split into lines. Strip leading tabs. Concat back to string.
			builtins.concatStringsSep "\n" (stripTabs (lib.strings.splitString "\n" text));
}
