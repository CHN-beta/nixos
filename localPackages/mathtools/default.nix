{ lib, buildPythonPackage }: buildPythonPackage rec
{
	pname = "mathtools";
	version = "1.2";
	src = lib.fetchPypi
	{
		inherit pname version;
		sha256 = lib.fakeSha256;
	};
}
