{ lib, fetchFromGitHub, buildPythonPackage, numpy, gdb }: buildPythonPackage
{
  name = "eigengdb";
  src = fetchFromGitHub
  {
    owner = "dmillard";
    repo = "eigengdb";
    rev = "c741edef3f07f33429056eff48d79a62733ed494";
    sha256 = "MTqOaWsKhWaPs3G5F/6bYZmQI5qS2hEGKGa3mwbgFaY=";
  };
  doCheck = false;
  buildInputs = [ gdb ];
  nativeBuildInputs = [ gdb ];
  propagatedBuildInputs = [ numpy ];
}
