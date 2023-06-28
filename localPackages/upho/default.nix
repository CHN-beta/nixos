{ lib, fetchFromGitHub, buildPythonPackage, numpy, h5py, phonopy }: buildPythonPackage rec
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
	doCheck = false;
	propagatedBuildInputs =
	[
		numpy h5py phonopy
		# (
		# 	buildPythonPackage
		# 	{
		# 		pname = "group";
		# 		inherit version;
		# 		src = "${src}/group";
		# 	}
		# )
	];
}
