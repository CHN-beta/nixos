{
  src,
  buildPythonPackage,
  setuptools,
  matplotlib,
}:
buildPythonPackage {
  name = "brokenaxes";
  pyproject = true;
  inherit src;
  build-system = [ setuptools ];
  dependencies = [ matplotlib ];
}
