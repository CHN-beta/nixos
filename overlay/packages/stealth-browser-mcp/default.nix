{
  lib,
  pkgs,
  stdenv,
  src,
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
}:
let
  workspace = uv2nix.lib.workspace.loadWorkspace { workspaceRoot = ./.; };

  overlay = workspace.mkPyprojectOverlay {
    sourcePreference = "wheel";
  };

  # Use Python 3.12 or 3.13
  python = pkgs.python313;

  # Build the python set
  pythonSet =
    (pkgs.callPackage pyproject-nix.build.packages {
      inherit python;
    }).overrideScope
      (
        lib.composeManyExtensions [
          pyproject-build-systems.overlays.default
          overlay
          # Inject the source code for the local package
          (final: prev: {
            stealth-browser-mcp = prev.stealth-browser-mcp.overrideAttrs (old: {
              inherit src;
            });
          })
        ]
      );

  # Create a virtualenv with all dependencies
  venv = pythonSet.mkVirtualEnv "stealth-browser-mcp-env" workspace.deps.all;

in
pkgs.writeShellApplication {
  name = "stealth-browser-mcp";
  runtimeInputs = [ venv ];
  text = ''
    python ${src}/src/server.py "$@"
  '';
}