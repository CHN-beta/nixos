{ lib, fetchFromGitHub, buildPythonPackage, numpy, h5py, phonopy }: buildPythonPackage rec
{
	pname = "upho";
	version = "0.6.6";
	src = fetchFromGitHub
	{
		owner = "CHN-beta";
		repo = "upho";
		rev = "45d4821bf5ef1d26ddf98e84bd497b1ddec9e057";
		sha256 = "sha256-J/DlCeGk70BTTTCcoN2ztruCnaA40kFiHDzJw3yAC24=";
	};
	doCheck = false;
	propagatedBuildInputs = [ numpy h5py phonopy ];
}
