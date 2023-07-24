inputs:
{
	config =
	{
		systemd.sleep.extraConfig =
		"
			SuspendState=freeze
			HibernateMode=shutdown
		";
		security.pam =
		{
			u2f = { enable = true; cue = true; authFile = ./u2f_keys; };
			services = builtins.listToAttrs (builtins.map (name: { inherit name; value = { u2fAuth = true; }; })
				[ "login" "sudo" "su" "kde" "polkit-1" ]);
		};
		environment.etc."channels/nixpkgs".source = inputs.topInputs.nixpkgs.outPath;
		# environment.pathsToLink = [ "/include" ];
		# environment.variables.CPATH = "/run/current-system/sw/include";
		# environment.variables.LIBRARY_PATH = "/run/current-system/sw/lib";
	};
}
