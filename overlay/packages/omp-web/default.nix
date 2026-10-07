{
  lib,
  rustPlatform,
  buildNpmPackage,
}:
let
  version =
    builtins.fromTOML (builtins.readFile ./backend/Cargo.lock)
    |> lib.getAttr "package"
    |> lib.filter (p: p.name == "omp-web")
    |> lib.head
    |> lib.getAttr "version";

  # Static SPA. Served by nginx, never embedded in the backend binary.
  ui = buildNpmPackage {
    pname = "omp-web-ui";
    inherit version;
    src = ./frontend;
    npmDepsHash = "sha256-Sy3ptqfos7hqwFDHZXTfSOzge/nBfXMHHhEqDgppOYg=";
    installPhase = ''
      runHook preInstall
      mkdir -p $out
      cp -r dist/. $out/
      runHook postInstall
    '';
  };

  backend = rustPlatform.buildRustPackage {
    pname = "omp-web-backend";
    inherit version;
    src = ./backend;
    cargoLock.lockFile = ./backend/Cargo.lock;
  };
in
{
  inherit backend ui;
}
