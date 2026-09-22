{
  lib,
  buildNpmPackage,
  src,
}:
buildNpmPackage {
  inherit (src)
    pname
    version
    src
    npmDepsHash
    ;
  meta = with lib; {
    description = "MCP server for Vikunja task management";
    homepage = "https://github.com/0xK3vin/vikunja-mcp";
    license = licenses.mit;
    maintainers = [ ];
    mainProgram = "vikunja-mcp";
  };
}
