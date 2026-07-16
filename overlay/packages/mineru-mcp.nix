{
  lib,
  buildPythonPackage,
  fetchFromGitHub,
  hatchling,
  mcp,
  requests,
  pypdf2,
  python-pptx,
  python-docx,
  typer,
}:

buildPythonPackage {
  pname = "mineru-converter-mcp-server";
  version = "1.0.0rc5";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "AvatarGanymede";
    repo = "MinerU-MCP";
    rev = "687c02966cba326771334111a8dfd09d3f05ef78";
    hash = "sha256-PseEyan2er2v93tNY1RRvDPEsF0QWzy498QoSU0f1zA=";
  };

  build-system = [ hatchling ];

  dependencies = [
    mcp
    requests
    pypdf2
    python-pptx
    python-docx
    typer
  ];

  doCheck = false;

  meta = {
    mainProgram = "mineru-converter-mcp-server";
    description = "MCP server for converting documents to Markdown using MinerU API";
    homepage = "https://github.com/AvatarGanymede/MinerU-MCP";
    license = lib.licenses.mit;
  };
}
