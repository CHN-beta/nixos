{
  src,
  buildPythonPackage,
  setuptools,
  cmake,
  buildProxy,
  distutils,
  numpy,
  scipy,
  matplotlib,
  pytest,
}:
buildPythonPackage {
  name = "pybinding";
  inherit src;
  pyproject = true;
  build-system = [
    setuptools
    cmake
    distutils
  ];
  dependencies = [
    numpy
    scipy
    matplotlib
    pytest
  ];
  dontUseCmakeConfigure = true;
  preBuild = ''source ${buildProxy}'';
  patches = [ ./fix.patch ];
}
