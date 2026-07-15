{
  fetchFromGitHub,
  buildPythonPackage,
  setuptools,
  wheel,
  fastmcp,
  httpx,
  pydantic,
  rich,
  pyalex,
  aiohttp,
}:

buildPythonPackage rec {
  pname = "alex-mcp";
  version = "4.8.2";
  pyproject = true;

  src = fetchFromGitHub {
    owner = "drAbreu";
    repo = "alex-mcp";
    rev = "v${version}";
    sha256 = "0j14l12arsasd31964pshpkgxzknbssrcyz4b1cgx7a6h8jl1jdf";
  };

  build-system = [
    setuptools
    wheel
  ];

  dependencies = [
    fastmcp
    httpx
    pydantic
    rich
    pyalex
    aiohttp
  ];

  doCheck = false;

  meta = {
    description = "MCP server for OpenAlex academic research API";
    homepage = "https://github.com/drAbreu/alex-mcp";
    mainProgram = "alex-mcp";
  };
}
