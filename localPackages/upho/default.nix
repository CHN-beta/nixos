{ lib, buildPythonPackage, fetchFromGitHub, numpy, h5py, phonopy, mathtools }: buildPythonPackage rec
{
	pname = "upho";
	version = "0.6.6";
	src = fetchFromGitHub
	{
		owner = "yuzie007";
		repo = "upho";
		rev = "v${version}";
		sha256 = "sha256-kOUwdXNrBfFglxGzO+qgRuSjiIOMafrgHkrV9blYs9c=";
	};
	propagatedBuildInputs = [ numpy h5py phonopy mathtools ];
}
