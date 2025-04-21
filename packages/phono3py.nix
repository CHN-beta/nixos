{
  src, buildPythonPackage,
  setuptools, ninja, cmake, setuptools-scm, scikit-build-core, nanobind,
  numpy, scipy, pyyaml, matplotlib, h5py, spglib, phonopy
}:
buildPythonPackage
{
  name = "phono3py";
  pyproject = true;
  inherit src;
  build-system = [ setuptools ninja cmake setuptools-scm scikit-build-core nanobind ];
  dependencies = [ numpy scipy pyyaml matplotlib h5py spglib phonopy ];
  dontUseCmakeConfigure = true;
  env.SETUPTOOLS_SCM_PRETEND_VERSION = "0";
}
