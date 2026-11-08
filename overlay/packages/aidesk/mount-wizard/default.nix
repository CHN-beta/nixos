{
  lib,
  pkgs,
}:
let
  # The wizard is a Windows-only binary, so build it with the mingw-w64 cross
  # toolchain: `pkgsCross.mingwW64.rustPlatform` supplies a rustc with the
  # `x86_64-pc-windows-gnu` standard library, and the cross binutils provide
  # `windres` for the embedded application manifest.
  cross = pkgs.pkgsCross.mingwW64;

  version = (builtins.fromTOML (builtins.readFile ./Cargo.toml)).package.version;
in
cross.rustPlatform.buildRustPackage {
  pname = "aidesk-mount-wizard";
  inherit version;

  src = lib.cleanSourceWith {
    src = ./.;
    filter =
      path: _type:
      let
        base = baseNameOf (toString path);
      in
      !(builtins.elem base [ "target" ]) && base != "result" && !(lib.hasPrefix "result-" base);
  };

  cargoLock.lockFile = ./Cargo.lock;

  nativeBuildInputs = [ cross.binutils ];

  doCheck = false;

  meta = with lib; {
    description = "Windows GUI wizard that maps the AIDesk (nas.chn.moe) workspace as a persistent SSHFS drive";
    license = licenses.mit;
    platforms = platforms.windows;
    mainProgram = "aidesk-mount-wizard.exe";
  };
}
