{ lib, fetchPypi, buildPythonPackage }: buildPythonPackage rec
{
  pname = "esbonio";
  version = "0.16.4";
  src = fetchPypi
  {
    inherit pname version;
    sha256 = "1MBNBLCEBD6HtlxEASc4iZaXYyNdih2MIHoxK84jMdI=";
  };
  doCheck = false;
}
