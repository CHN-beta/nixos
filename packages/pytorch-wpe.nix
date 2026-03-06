{ src, buildPythonPackage, setuptools, numpy, torch, torch-complex }:
buildPythonPackage
{
  name = "pytorch-wpe";
  inherit src;
  pyproject = true;
  build-system = [ setuptools ];
  dependencies = [ numpy torch torch-complex ];
}
