# from https://github.com/NixOS/nixpkgs/pull/267893
{
  buildPythonPackage, src,
  ipywidgets, jupyter-packaging, jupyterlab-widgets, numpy, setuptools, versioneer, wheel, notebook
}: buildPythonPackage
{
  name = "nglview";
  pyproject = true;
  inherit src;
  build-system = [ jupyter-packaging setuptools versioneer wheel ];
  dependencies = [ ipywidgets jupyterlab-widgets numpy notebook ];
  postPatch =
  ''
    substituteInPlace pyproject.toml \
      --replace "jupyter_packaging~=0.7.9" "jupyter_packaging" \
      --replace '"versioneer-518"' ""
  '';
}