{ src, buildPythonPackage, setuptools, torch, packaging, pytest-runner }: buildPythonPackage
{
  name = "torch-complex";
  inherit src;
  pyproject = true;
  build-system = [ setuptools ];
  dependencies = [ torch packaging pytest-runner ];
  pythonImportsCheck = [ "torch_complex" ];
}
