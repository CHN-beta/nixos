{ src, buildPythonPackage, setuptools, setuptools-scm, pymatgen }: buildPythonPackage
{
  name = "pyrho";
  pyproject = true;
  inherit src;
  build-system = [ setuptools setuptools-scm ];
  dependencies = [ pymatgen ];
  env.SETUPTOOLS_SCM_PRETEND_VERSION = "0";
  pythonImportsCheck = [ "pyrho" ];
}
