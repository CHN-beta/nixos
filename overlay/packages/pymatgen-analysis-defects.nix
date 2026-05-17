{ src, buildPythonPackage, setuptools, pymatgen, scikit-image, numpy, pyrho, versioningit, pydefect }:
buildPythonPackage
{
  name = "pymatgen-analysis-defects";
  pyproject = true;
  inherit (src) src version;
  build-system = [ setuptools versioningit ];
  dependencies = [ pymatgen scikit-image numpy pyrho pydefect ];
  pythonImportsCheck = [ "pymatgen.analysis.defects" ];
}
