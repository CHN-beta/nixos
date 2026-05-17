{
  src, buildPythonPackage, setuptools,
  numpy, pymatgen, pymatgen-analysis-defects, matplotlib, ase, pandas, seaborn, hiphive, monty, click,
  importlib-metadata
}: buildPythonPackage
{
  pname = "shakenbreak";
  pyproject = true;
  inherit (src) src version;
  build-system = [ setuptools ];
  dependencies =
    [ numpy pymatgen pymatgen-analysis-defects matplotlib ase pandas seaborn hiphive monty click importlib-metadata ];
  pythonImportsCheck = [ "shakenbreak" ];
  patches = [ ./remove-doped.patch ];
  # dontCheckRuntimeDeps = true;
}
