{
  src,
  buildPythonPackage,
  setuptools,
  setuptools-scm,
  matplotlib,
  numpy,
  packaging,
}:
buildPythonPackage {
  pname = "cmcrameri";
  pyproject = true;
  inherit (src) src version;
  build-system = [
    setuptools
    setuptools-scm
  ];
  dependencies = [
    matplotlib
    numpy
    packaging
  ];
  pythonImportsCheck = [ "cmcrameri" ];
}
