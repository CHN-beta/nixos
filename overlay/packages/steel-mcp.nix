{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
}:

buildNpmPackage rec {
  pname = "steel-mcp";
  version = "2.0.0-rc.8";

  src = fetchFromGitHub {
    owner = "steel-dev";
    repo = "steel-mcp-server";
    rev = "f88128a12f18cbebad2a83a573a8086ce72ac625";
    hash = "sha256-VNeE0qRb2VrCZtn5ZN5SvwkverniJmle0ztKPDfKx0I=";
  };

  npmDepsHash = "sha256-Y0IrX69tvQ6QgVZDJWPTQ/yyOZ8KEUHqwJwSZG+12Ok=";

  dontNpmBuild = false;

  # Tests likely require a browser or external connectivity
  doCheck = false;

  meta = {
    description = "MCP server for Steel cloud browsers";
    homepage = "https://steel.dev";
    license = lib.licenses.mit;
    mainProgram = "steel-mcp";
  };
}