{
  src,
  lib,
  buildPythonPackage,
  setuptools,
  setuptools-scm,
  pymatgen,
  pydantic,
  pydantic-settings,
  pymatgen-io-validation,
  blake3,
  inflect,
  pubchempy,
}:
buildPythonPackage rec {
  pname = "emmet-core";
  version = lib.removePrefix "v" src.tag;
  pyproject = true;
  inherit src;
  build-system = [
    setuptools
    setuptools-scm
  ];
  dependencies = [
    pymatgen
    pydantic
    pydantic-settings
    pymatgen-io-validation
    blake3
    inflect
    pubchempy
  ];
  pythonImportsCheck = [ "emmet.core" ];
  sourceRoot = "source/emmet-core";
}
