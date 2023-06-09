{ pkgs, ... }@inputs:
{
	config.environment.systemPackages = with inputs.pkgs;
	[
		ovito paraview # vsim vesta
		(python3.withPackages (ps: with ps; [ phonopy ]))
		mathematica octave root
	];
}
