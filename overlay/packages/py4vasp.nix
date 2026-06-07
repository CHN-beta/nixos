{
  src,
  buildPythonPackage,
  poetry-core,
  numpy,
  h5py,
  pandas,
  ase,
  plotly,
  kaleido,
  ipython,
  scipy,
  nglview,
}:
buildPythonPackage {
  name = "py4vasp";
  pyproject = true;
  inherit src;
  build-system = [ poetry-core ];
  dependencies = [
    numpy
    h5py
    pandas
    ase
    plotly
    kaleido
    ipython
    scipy
    nglview
  ];
}
