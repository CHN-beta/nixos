{
  lib,
  rustPlatform,
  pkg-config,
  buildNpmPackage,
}:
let
  version =
    ./backend/Cargo.lock
    |> builtins.readFile
    |> fromTOML
    |> lib.getAttr "package"
    |> lib.filter (p: p.name == "freshman-followup")
    |> lib.head
    |> lib.getAttr "version";

  ui = buildNpmPackage {
    pname = "freshman-followup-ui";
    inherit version;
    src = ./frontend;
    npmDepsHash = "sha256-ynNAWMchVqlB9eDXoMVQW5/vvQf4piVj5UunQNzDazo=";
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib/freshman-followup-ui
      cp -r dist package.json $out/lib/freshman-followup-ui/
      ln -s dist $out/lib/freshman-followup-ui/ui
      runHook postInstall
    '';
  };

  backend = rustPlatform.buildRustPackage {
    pname = "freshman-followup";
    inherit version;
    src = ./backend;
    cargoLock.lockFile = ./backend/Cargo.lock;
    nativeBuildInputs = [
      pkg-config
    ];
  };
in
{
  inherit backend ui;
}
