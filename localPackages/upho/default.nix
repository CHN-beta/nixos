{ lib, fetchFromGitHub, buildPythonPackage, numpy, h5py, phonopy }: buildPythonPackage rec
{
	pname = "upho";
	version = "0.6.6";
	src = fetchFromGitHub
	{
		owner = "CHN-beta";
		repo = "upho";
		rev = "0f27ac6918e8972c70692816438e4ac37ec6b348";
		sha256 = "sha256-NvoV+AUH9MmGT4ohrLAAvpLs8APP2DOKYlZVliHrVRM=";
	};
	doCheck = false;
	propagatedBuildInputs = [ numpy h5py phonopy ];
}
