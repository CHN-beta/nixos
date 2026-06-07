{
  src,
  buildPythonPackage,
  setuptools,
  tabulate,
  matplotlib,
  numpy,
  pymatgen,
  pymatgen-analysis-defects,
  shakenbreak,
  ase,
  pandas,
  pydefect,
  filelock,
  vise,
  cmcrameri,
  matplotlib-label-lines,
  dscribe,
}:
buildPythonPackage {
  pname = "doped";
  pyproject = true;
  inherit (src) src version;
  build-system = [ setuptools ];
  dependencies = [
    tabulate
    matplotlib
    numpy
    pymatgen
    pymatgen-analysis-defects
    shakenbreak
    ase
    pandas
    pydefect
    filelock
    vise
    cmcrameri
    matplotlib-label-lines
    dscribe
  ];
  pythonImportsCheck = [ "doped" ];
}
