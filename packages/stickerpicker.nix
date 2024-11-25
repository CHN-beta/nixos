{ src, buildPythonApplication, aiohttp, yarl, pillow, telethon, cryptg, python-magic }: buildPythonApplication
{
  name = "stickerpicker";
  inherit src;
  propagatedBuildInputs = [ aiohttp yarl pillow telethon cryptg python-magic ];
}
