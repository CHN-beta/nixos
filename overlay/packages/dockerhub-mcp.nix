{
  lib,
  stdenv,
  nodejs,
  src,
}:
stdenv.mkDerivation {
  inherit (src)
    pname
    version
    src
    npmDeps
    ;
  nativeBuildInputs = [ nodejs ];
  buildPhase = ''
    runHook preBuild
    export HOME=$(mktemp -d)
    export npm_config_cache=$(mktemp -d)
    cp -r $npmDeps/* $npm_config_cache/
    chmod -R +w $npm_config_cache
    npm install --offline --no-audit --no-fund --ignore-scripts --legacy-peer-deps
    patchShebangs node_modules
    npm run build
    runHook postBuild
  '';
  installPhase = ''
    runHook preInstall
    mkdir -p $out/lib/dockerhub-mcp $out/bin
    cp -r dist node_modules package.json $out/lib/dockerhub-mcp/
    cat > $out/bin/dockerhub-mcp <<SH
    #!/bin/sh
    exec ${nodejs}/bin/node $out/lib/dockerhub-mcp/dist/index.js "\$@"
    SH
    chmod +x $out/bin/dockerhub-mcp
    runHook postInstall
  '';
  meta = with lib; {
    description = "Docker Hub MCP Server";
    homepage = "https://github.com/docker/hub-mcp";
    license = licenses.asl20;
    maintainers = [ ];
    mainProgram = "dockerhub-mcp";
  };
}
