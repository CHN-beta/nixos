{ src, python3Packages, models }: python3Packages.buildPythonApplication
{
  name = "vocotype";
  inherit src;
  pyproject = true;
  build-system = with python3Packages; [ setuptools ];
  dependencies = with python3Packages;
    [ sounddevice librosa soundfile funasr-onnx jieba pygobject3 modelscope torch pyrime ];
  patches = [ ./fix.patch ./vocotype-2.1.2-download-models.patch ./vocotype-2.1.2-fcitx5-system-install.patch ];
  postPatch =
  ''
    cp fcitx5/backend/rime_handler.py app/rime_handler.py
    substituteInPlace app/download_models.py --replace-fail /usr/share $out/share
  '';
  postInstall =
  ''
    cp fcitx5/backend/fcitx5_server.py $out/bin/vocotype-fcitx5-backend
    mkdir -p $out/share/vocotype/models
    cp -r ${models}/* $out/share/vocotype/models
  '';
}
