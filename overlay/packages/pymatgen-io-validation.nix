{
  src,
  buildPythonPackage,
  setuptools,
  pymatgen,
  numpy,
  requests,
  pydantic,
  pydantic-settings,
  versioningit,
}:
buildPythonPackage {
  pname = "pymatgen-io-validation";
  pyproject = true;
  inherit (src) src version;
  build-system = [
    setuptools
    versioningit
  ];
  dependencies = [
    pymatgen
    numpy
    requests
    pydantic
    pydantic-settings
  ];
  pythonImportsCheck = [ "pymatgen.io.validation" ];
}
