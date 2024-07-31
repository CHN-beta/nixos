{
  lib, fetchFromGitHub, buildPythonPackage,
  # general dependencies:
  tqdm, munch, torch, opencv, requests, einops, transformers, tokenizers, numpy, pillow, pyyaml, pandas, timm,
  albumentations,
  # gui
  pyqt6, pyqt6-webengine, pyside6, pynput, screeninfo,
  # api
  streamlit, fastapi, uvicorn, python-multipart,
  # training
  # python-Levenshtein, torchtext, imagesize
  # highlight
  pygments
}: buildPythonPackage
{
  name = "pix2tex";
  src = fetchFromGitHub
  {
    owner = "lukas-blecher";
    repo = "LaTeX-OCR";
    rev = "1781514fb8c92ea9f94057295fdae0e683f4648e";
    hash = "sha256-I3B8eH7zV2zIogDt9znkEzp4EeBjY6NfI4jsl+v/8aM=";
  };
  patches = [ ./remove-version-requires.patch ];
  propagatedBuildInputs =
  [
    tqdm munch torch opencv requests einops transformers tokenizers numpy pillow pyyaml pandas timm albumentations
    pyqt6 pyqt6-webengine pyside6 pynput screeninfo
    streamlit fastapi uvicorn python-multipart
    pygments
  ];
}
