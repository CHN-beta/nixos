{ src, buildPythonPackage, setuptools, filelock, requests, tqdm, urllib3 }: buildPythonPackage
{
  name = "modelscope";
  inherit src;
  pyproject = true;
  build-system = [ setuptools ];
  dependencies = [ filelock requests tqdm urllib3 ];
}
