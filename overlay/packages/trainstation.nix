{
  src,
  buildPythonPackage,
  setuptools,
  scipy,
  numpy,
  scikit-learn,
}:
buildPythonPackage {
  pname = "trainstation";
  pyproject = true;
  inherit (src) src version;
  build-system = [ setuptools ];
  dependencies = [
    scipy
    numpy
    scikit-learn
  ];
  pythonImportsCheck = [ "trainstation" ];
}
