{ buildPythonPackage, setuptools, funasr, fetchPypi, onnxruntime, onnx, kaldi-native-fbank }:
buildPythonPackage rec
{
  pname = "funasr-onnx";
  version = "0.4.1";
  src = fetchPypi
  {
    pname = "funasr_onnx";
    inherit version;
    hash = "sha256-w7QVSw48A17FVR037yKL5wK+nOVC7KULUNtDmz4/q80==";
  };
  pyproject = true;
  patches = [ ./fix.patch ];
  build-system = [ setuptools ];
  dependencies = [ funasr onnxruntime onnx kaldi-native-fbank ];
  pythonImportsCheck = [ "funasr_onnx" ];
}
