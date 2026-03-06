{ src, buildPythonPackage, setuptools, cmake, pybind11, torch, wheel, gtest, kissfft }: buildPythonPackage
{
  name = "kaldi-native-fbank";
  inherit src;
  pyproject = true;
  build-system = [ setuptools wheel cmake ];
  dependencies = [ torch ];
  dontUseCmakeConfigure = true;
  env.KALDI_NATIVE_FBANK_CMAKE_ARGS = builtins.concatStringsSep " "
  [
    "-DCMAKE_BUILD_TYPE=Release" "-DFETCHCONTENT_SOURCE_DIR_PYBIND11=${pybind11.src}"
    "-DFETCHCONTENT_SOURCE_DIR_GOOGLETEST=${gtest.src}" "-DFETCHCONTENT_SOURCE_DIR_KISSFFT=${kissfft.src}"
  ];
}
