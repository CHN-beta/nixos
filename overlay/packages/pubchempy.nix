{
  src,
  buildPythonPackage,
  setuptools,
}:
buildPythonPackage {
  pname = "pubchempy";
  inherit (src) src version;
  pyproject = true;
  build-system = [ setuptools ];
  dependencies = [ ];
  pythonImportsCheck = [ "pubchempy" ];
}
