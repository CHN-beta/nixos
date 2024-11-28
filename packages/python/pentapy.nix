{ src, buildPythonPackage, setuptools, wheel }: buildPythonPackage
{
  name = "penapy";
  inherit src;
  pyproject = true;
}