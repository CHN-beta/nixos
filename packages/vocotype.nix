{ src, python3Packages }: python3Packages.buildPythonApplication
{
  name = "vocotype";
  inherit src;
  pyproject = true;
  build-system = with python3Packages; [ setuptools ];
  dependencies = with python3Packages; [ sounddevice librosa soundfile funasr-onnx jieba pygobject3 modelscope torch ];
}
