{ lib, fetchPypi, buildPythonPackage }: buildPythonPackage rec
{
  pname = "esbonio";
  version = "0.16.3";
  src = fetchPypi
  {
    inherit pname version;
    sha256 = "1ggxdzl95fy0zxpyd1pcylhif1x604wk4wy7sv9322hc84b708zx";
  };
  doCheck = false;
}
