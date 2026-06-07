{
  src, buildPythonPackage,
  setuptools, ninja, cmake, setuptools-scm, scikit-build-core, nanobind,
  numpy, scipy, pyyaml, matplotlib, h5py, spglib, phonopy
}:
buildPythonPackage
{
  pname = "phono3py";
  inherit (src) version src;
  patches = [ ./nanobind.patch ];
  pyproject = true;
  build-system = [ setuptools ninja cmake setuptools-scm scikit-build-core nanobind ];
  dependencies = [ numpy scipy pyyaml matplotlib h5py spglib phonopy ];
  dontUseCmakeConfigure = true;
}
