{
  lib,
  src,
  buildPythonPackage,
  setuptools,
  setuptools-scm,
  pymatgen,
}:
buildPythonPackage rec {
  pname = "pyrho";
  version = lib.removePrefix "v" src.tag;
  pyproject = true;
  inherit src;
  build-system = [
    setuptools
    setuptools-scm
  ];
  dependencies = [ pymatgen ];
  env.SETUPTOOLS_SCM_PRETEND_VERSION = version;
  pythonImportsCheck = [ "pyrho" ];
}
