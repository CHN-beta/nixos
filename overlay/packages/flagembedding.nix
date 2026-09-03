{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  setuptools,
  torch,
  transformers,
  datasets,
  accelerate,
  sentence-transformers,
  peft,
  sentencepiece,
  protobuf,
  numpy,
  tqdm,
}:
buildPythonPackage rec {
  pname = "flagembedding";
  version = "1.4.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "FlagOpen";
    repo = "FlagEmbedding";
    rev = "fd1a2bdf69488ffebe0327999d4400d8c8058a0b";
    hash = "sha256-rUI8zFKyEVrEA4cglSQWRfAUdk0s7nHJpiv2uoaBFmc=";
  };

  build-system = [ setuptools ];

  dependencies = [
    torch
    transformers
    datasets
    accelerate
    sentence-transformers
    peft
    sentencepiece
    protobuf
    numpy
    tqdm
  ];

  # This service only uses the inference API; ir-datasets is for evaluation.
  pythonRemoveDeps = [ "ir-datasets" ];

  # Upstream tests download models and exercise training and multi-GPU paths.
  doCheck = false;

  pythonImportsCheck = [ "FlagEmbedding" ];

  meta = {
    description = "Retrieval and embedding toolkit from BAAI";
    homepage = "https://github.com/FlagOpen/FlagEmbedding";
    license = lib.licenses.mit;
  };
}
