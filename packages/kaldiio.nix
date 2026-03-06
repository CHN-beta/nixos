{ src, buildPythonPackage, setuptools, pytest-runner, numpy }: buildPythonPackage
{
  name = "kaldiio";
  inherit src;
  pyproject = true;
  build-system = [ setuptools ];
  dependencies = [ pytest-runner numpy ];
}
