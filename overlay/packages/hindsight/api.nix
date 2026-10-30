{
  lib,
  pkgs,
  python,
  src,
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
}:
let
  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = src; };

  pythonSet = (pkgs.callPackage pyproject-nix.build.packages { inherit python; }).overrideScope (
    lib.composeManyExtensions [
      pyproject-build-systems.overlays.wheel
      (workspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
        dependencies = {
          hindsight-api-slim = [ ];
        };
      })
    ]
  );
in
(pythonSet.mkVirtualEnv "hindsight-api-1.1.0" { hindsight-api-slim = [ ]; }).overrideAttrs {
  meta = {
    description = "Hindsight: Agent Memory That Learns";
    homepage = "https://github.com/vectorize-io/hindsight";
    license = lib.licenses.mit;
    mainProgram = "hindsight-api";
  };
}
