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
(pythonSet.mkVirtualEnv "hindsight-api-1.1.0" { hindsight-api-slim = [ ]; }).overrideAttrs (old: {
  postInstall = (old.postInstall or "") + ''
    cp ${./bank_auth.py} $out/${python.sitePackages}/hindsight_bank_auth.py
  '';
  meta = {
    description = "Hindsight: Agent Memory That Learns";
    homepage = "https://github.com/vectorize-io/hindsight";
    license = lib.licenses.mit;
    mainProgram = "hindsight-api";
  };
})
