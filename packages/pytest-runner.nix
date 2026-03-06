{ src, buildPythonPackage, setuptools, setuptools-scm }:
buildPythonPackage
{
  pname = "pytest-runner";
  version = "6.0.0";
  inherit src;
  pyproject = true;
  build-system = [ setuptools setuptools-scm ];
}
