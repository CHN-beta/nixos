{ src, buildPythonPackage, cython, autopxd2, meson-python, librime, pkg-config, cmake, platformdirs, wcwidth }:
buildPythonPackage
{
  name = "pyrime";
  inherit src;
  pyproject = true;
  build-system = [ cython autopxd2 meson-python ];
  dependencies = [ platformdirs wcwidth ];
  buildInputs = [ librime ];
  nativeBuildInputs = [ pkg-config cmake ];
  dontUseCmakeConfigure = true;
}
