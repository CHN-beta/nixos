{
  lib,
  rustPlatform,
  fetchFromGitHub,
}:
rustPlatform.buildRustPackage rec {
  pname = "matrix-mcp";
  version = "0.2.4";

  src = fetchFromGitHub {
    owner = "qechris";
    repo = "matrix-mcp";
    rev = "v${version}";
    hash = "sha256-BGvZn6b6XnxAP2Cw7s8jdra3oyvYh0Jeqre6Z891UoU=";
  };

  cargoHash = "sha256-G0ayfbNxQEGYKPqr1qWfxNDjEJpcEPaUFQ072314P4o=";

  doCheck = false;

  meta = {
    description = "Model Context Protocol (MCP) server for the Matrix chat protocol";
    homepage = "https://github.com/qechris/matrix-mcp";
    license = lib.licenses.mit;
    mainProgram = "matrix-mcp";
  };
}
