inputs:
{
	config.environment.systemPackages = with inputs.pkgs;
	[
		ovito paraview localPackages.vesta # vsim
		(python3.withPackages (ps: with ps;
		[
			phonopy inquirerpy requests tqdm
			localPackages.upho
		]))
		mathematica octave root cling
	];
}
