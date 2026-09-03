{
  lib,
  python3Packages,
}:
python3Packages.buildPythonApplication {
  pname = "bge-m3-server";
  version = "0.1.0";
  pyproject = true;

  src = ./.;

  build-system = [ python3Packages.setuptools ];

  dependencies = with python3Packages; [
    fastapi
    flagembedding
    numpy
    torch
    uvicorn
  ];

  nativeCheckInputs = with python3Packages; [
    httpx
    pytestCheckHook
  ];

  pythonImportsCheck = [ "bge_m3_server" ];

  meta = {
    description = "OpenAI-compatible BGE-M3 embedding server with dense, sparse, and ColBERT outputs";
    license = lib.licenses.mit;
    mainProgram = "bge-m3-server";
  };
}
