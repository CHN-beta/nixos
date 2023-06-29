{ lib, fetchFromGitHub, buildPythonPackage, numpy, h5py, phonopy }: buildPythonPackage rec
{
	pname = "upho";
	version = "0.6.6";
	src = fetchFromGitHub
	{
		owner = "CHN-beta";
		repo = "upho";
		rev = "1468521477f2a6d112abd7a3e182c6a0ccb6f6c0";
		sha256 = "sha256-ZtGUGpxesiQL/76zSTQjt3UK+JoRNs/C2g+3PC3eADE=";
	};
	doCheck = false;
	propagatedBuildInputs = [ numpy h5py phonopy ];
}
