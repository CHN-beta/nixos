{
  src,
  buildPythonPackage,
  setuptools,
  pymatgen-core,
  seekpath,
  more-itertools,
  phonopy,
  mp-api,
  num2words,
}:
buildPythonPackage {
  name = "vise";
  pyproject = true;
  inherit src;
  build-system = [ setuptools ];
  dependencies = [
    pymatgen-core
    seekpath
    more-itertools
    phonopy
    mp-api
    num2words
  ];
  pythonImportsCheck = [ "vise" ];
}
