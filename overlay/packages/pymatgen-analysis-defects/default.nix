{ src, buildPythonPackage, setuptools, pymatgen, scikit-image, numpy, pyrho, versioningit }: buildPythonPackage
{
  name = "pymatgen-analysis-defects";
  pyproject = true;
  inherit src;
  build-system = [ setuptools versioningit ];
  dependencies = [ pymatgen scikit-image numpy pyrho ];
  pythonImportsCheck = [ "pymatgen.analysis.defects" ];
  patches = [ ./version.patch ];
}
