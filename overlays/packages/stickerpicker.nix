{ src, buildPythonApplication, aiohttp, yarl, pillow, telethon, cryptg, python-magic, setuptools }:
buildPythonApplication
{
  name = "stickerpicker";
  inherit src;
  propagatedBuildInputs = [ aiohttp yarl pillow telethon cryptg python-magic ];
  pyproject = true;
  build-system = [ setuptools ];
}
