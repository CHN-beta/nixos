{ src, buildPythonPackage, setuptools, ase, h5py, numba, numpy, pandas, scipy, spglib, sympy, trainstation }:
buildPythonPackage
{
  pname = "hiphive";
  pyproject = true;
  inherit (src) src version;
  build-system = [ setuptools ];
  dependencies = [ ase h5py numba numpy pandas scipy spglib sympy trainstation ];
  pythonImportsCheck = [ "hiphive" ];
}
