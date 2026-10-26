{
  lib,
  bun2nix,
  src,
}:
bun2nix.mkDerivation {
  pname = "cliproxyapi-management";
  packageJson = "${src}/package.json";

  inherit src;

  # The UI imports transitive dependencies (e.g. react-router, motion-dom),
  # which are only resolvable from a hoisted node_modules tree.
  bunInstallFlags = "--linker=hoisted";

  bunDeps = bun2nix.fetchBunDeps {
    bunNix = "${src}/bun.nix";
  };

  buildPhase = ''
    runHook preBuild
    bun run build
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cp dist/index.html $out
    runHook postInstall
  '';

  meta = with lib; {
    description = "Management web UI for CLIProxyAPI";
    homepage = "https://github.com/router-for-me/Cli-Proxy-API-Management-Center";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
  };
}
