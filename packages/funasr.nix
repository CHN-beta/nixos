{
  src, buildPythonPackage, setuptools,
  numpy, pytest-runner, scipy, librosa, jamo, pyyaml, soundfile, kaldiio, sentencepiece, jieba, pytorch-wpe,
  editdistance, oss2, tqdm, umap-learn, jaconv, hydra-core, tensorboardx, requests, modelscope, torch-complex,
  torchaudio
}: buildPythonPackage
{
  name = "funasr";
  inherit src;
  pyproject = true;
  build-system = [ setuptools ];
  dependencies =
  [
    numpy pytest-runner scipy librosa jamo pyyaml soundfile kaldiio sentencepiece jieba pytorch-wpe editdistance oss2
    tqdm umap-learn jaconv hydra-core tensorboardx requests modelscope torch-complex torchaudio
  ];
  pythonImportsCheck = [ "funasr" ];
}
