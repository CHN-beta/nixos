{
  src,
  buildPythonPackage,
  setuptools,
  matplotlib,
  hatchling,
  more-itertools,
}:
buildPythonPackage rec {
  name = "matplotlib-label-lines";
  pyproject = true;
  inherit src;
  build-system = [
    setuptools
    hatchling
  ];
  dependencies = [
    matplotlib
    more-itertools
  ];
  pythonImportsCheck = [ "labellines" ];
}
