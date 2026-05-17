{
  src, buildPythonPackage, setuptools,
  pymatgen-core, numpy, vise, adjusttext, matplotlib-label-lines, emmet-core, boto3, pyarrow, deltalake, scikit-image
}:
buildPythonPackage
{
  name = "pydefect";
  pyproject = true;
  inherit src;
  build-system = [ setuptools ];
  dependencies =
    [ pymatgen-core numpy vise adjusttext matplotlib-label-lines emmet-core boto3 pyarrow deltalake scikit-image ];
  pythonImportsCheck = [ "pydefect" ];
}
