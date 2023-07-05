inputs:
{
	config.environment.systemPackages = with inputs.pkgs;
	[
		ovito paraview localPackages.vesta # vsim
		(python3.withPackages (ps: with ps;
		[
			phonopy inquirerpy requests tqdm tensorflow keras
			localPackages.upho localPackages.spectral
		]))
		mathematica octave root cling gfortran
		qchem.quantum-espresso
	];
}
