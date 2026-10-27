{
  lib,
  rustPlatform,
}:
let
  version =
    ./Cargo.lock
    |> builtins.readFile
    |> fromTOML
    |> lib.getAttr "package"
    |> lib.filter (p: p.name == "aidesk-backend")
    |> lib.head
    |> lib.getAttr "version";
in
rustPlatform.buildRustPackage {
  pname = "aidesk-backend";
  inherit version;

  # Keep the build source small: Cargo's target directory and Nix results are
  # never inputs.
  src = lib.cleanSourceWith {
    src = ./.;
    filter =
      path: _type:
      let
        base = baseNameOf (toString path);
      in
      !(builtins.elem base [
        "target"
      ]) && base != "result" && !(lib.hasPrefix "result-" base);
  };

  cargoLock.lockFile = ./Cargo.lock;

  meta = with lib; {
    description = "AIDesk backend: Rust implementation of the omp-web API";
    license = licenses.mit;
    mainProgram = "aidesk-backend";
    maintainers = [ ];
    platforms = platforms.unix;
  };
}
