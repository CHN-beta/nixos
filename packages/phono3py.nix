{ src, buildPythonPackage, setuptools, ninja, cmake, setuptools-scm, scikit-build-core, nanobind, numpy }:
buildPythonPackage
{
  name = "phono3py";
  pyproject = true;
  inherit src;
  build-system = [ setuptools ninja cmake setuptools-scm scikit-build-core nanobind ];
  dependencies = [ numpy ];
  dontUseCmakeConfigure = true;
  env.SETUPTOOLS_SCM_PRETEND_VERSION = "0";
}
