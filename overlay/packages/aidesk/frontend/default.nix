{
  lib,
  bun2nix,
}:
let
  # The dev tree carries build artefacts and an installed node_modules; keep
  # them out of the Nix source so evaluation and hashing stay deterministic.
  src = lib.cleanSourceWith {
    src = ./.;
    filter =
      path: _type:
      let
        name = baseNameOf (toString path);
      in
      !(
        builtins.elem name [
          "node_modules"
          "dist"
          ".vite"
        ]
        || lib.hasSuffix ".tsbuildinfo" name
        || name == "result"
        || lib.hasPrefix "result-" name
      );
  };
in
bun2nix.mkDerivation {
  pname = "aidesk-frontend";
  version = (builtins.fromJSON (builtins.readFile ./package.json)).version;

  inherit src;
  packageJson = "${src}/package.json";

  # Vite resolves transitive dependencies (react-dom/client, mermaid internals)
  # from a hoisted node_modules tree.
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
    mkdir -p $out
    cp -r dist/. $out/
    runHook postInstall
  '';

  meta = with lib; {
    description = "Static SPA frontend for AIDesk, a web UI for the oh-my-pi (omp) coding agent";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
  };
}
