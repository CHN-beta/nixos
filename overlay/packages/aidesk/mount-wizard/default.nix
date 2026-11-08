{
  lib,
  pkgs,
}:
let
  # The wizard is a Windows-only binary, so build it with the mingw-w64 cross
  # toolchain configured for the UCRT runtime (`pkgsCross.ucrt64`), matching a
  # modern Windows 10/11 userland. `rustPlatform` supplies a rustc with the
  # `x86_64-pc-windows-gnu` standard library, and the cross binutils provide
  # `windres`, which `build.rs` uses to embed the application manifest.
  cross = pkgs.pkgsCross.ucrt64;

  version = (builtins.fromTOML (builtins.readFile ./Cargo.toml)).package.version;

  # Runtime installers shipped in the zip's `deps/` subdirectory so the wizard
  # can install its dependencies offline (see src/deps.rs). Both are pinned
  # upstream releases; SSHFS-Win bundles its own `ssh.exe`/`sshfs.exe`, so
  # WinFsp + SSHFS-Win is the complete runtime requirement.
  winfsp = pkgs.fetchurl {
    name = "winfsp-2.1.25156.msi";
    url = "https://github.com/winfsp/winfsp/releases/download/v2.1/winfsp-2.1.25156.msi";
    hash = "sha256-Bzpw4A93Qj40vtmLhuYA3vkzk7pYIiBPrFeikyTbn3o=";
  };

  sshfs-win = pkgs.fetchurl {
    name = "sshfs-win-3.5.20357-x64.msi";
    url = "https://github.com/winfsp/sshfs-win/releases/download/v3.5.20357/sshfs-win-3.5.20357-x64.msi";
    hash = "sha256-Flfjl/jc4cLS4yIAB/nJ+IJjGIK5vsRgj3g16H3NCWw=";
  };
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

  nativeBuildInputs = [
    cross.binutils
    pkgs.zip
  ];

  doCheck = false;

  postInstall = ''
    stage=$(mktemp -d)

    # Zip layout: the wizard executable at the top level, the offline
    # installers in `deps/`, which is where src/deps.rs looks for them first.
    cp $out/bin/aidesk-mount-wizard.exe "$stage/aidesk-mount-wizard.exe"
    mkdir -p "$stage/deps"
    cp ${winfsp} "$stage/deps/${winfsp.name}"
    cp ${sshfs-win} "$stage/deps/${sshfs-win.name}"

    # Fixed timestamps keep the archive reproducible under SOURCE_DATE_EPOCH.
    TZ=UTC find "$stage" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +

    mkdir -p $out
    (cd "$stage" && TZ=UTC ${pkgs.zip}/bin/zip -9 -X -r $out/aidesk-mount-wizard.zip .)
    rm -rf "$stage" $out/bin
  '';

  meta = with lib; {
    description = "Windows GUI wizard that maps the AIDesk (nas.chn.moe) workspace as a persistent SSHFS drive";
    longDescription = ''
      Windows x64 bundle: `aidesk-mount-wizard.zip` contains the wizard
      executable at the top level and the pinned WinFsp and SSHFS-Win MSI
      installers in its `deps/` subdirectory.
    '';
    license = licenses.mit;
    platforms = platforms.windows;
  };
}
