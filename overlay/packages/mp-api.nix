{
  src,
  lib,
  buildPythonPackage,
  setuptools,
  pymatgen,
  setuptools-scm,
  emmet-core,
  boto3,
  pyarrow,
  deltalake,
}:
buildPythonPackage rec {
  pname = "mp-api";
  version = lib.removePrefix "v" src.tag;
  pyproject = true;
  inherit src;
  build-system = [
    setuptools
    setuptools-scm
    emmet-core
    boto3
    pyarrow
    deltalake
  ];
  dependencies = [ pymatgen ];
  pythonImportsCheck = [ "mp_api" ];
}
