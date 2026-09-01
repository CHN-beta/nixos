{
  lib,
  buildGoModule,
  fetchFromGitHub,
}:
buildGoModule rec {
  pname = "translate-mcp";
  version = "1.0.0-unstable-2026-07-14";

  src = fetchFromGitHub {
    owner = "mohammadraufzahed";
    repo = "translate-mcp";
    rev = "9da3d617896de89b9deaef684951ef73a806e138";
    hash = "sha256-3+VuvINaQo3K5N38KFfT0vPzzemHCNWF5WY5A06ZVr4=";
  };

  vendorHash = "sha256-1Y+YWcArXB7h9Z6xEFuE+fIT7ISk8qrxIJJRAmzrhK4=";

  subPackages = [ "cmd/translate-mcp" ];

  meta = with lib; {
    description = "A production-grade, multi-provider translation server for the Model Context Protocol (MCP)";
    homepage = "https://github.com/mohammadraufzahed/translate-mcp";
    license = licenses.mit;
    mainProgram = "translate-mcp";
  };
}
