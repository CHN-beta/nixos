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

  # Runtime installers, pinned upstream releases. `build.rs` compiles these
  # into the executable (see `emit_embedded_installers`), so the wizard can
  # install its dependencies offline from a single-file download. SSHFS-Win
  # bundles its own `ssh.exe`/`sshfs.exe`, so WinFsp + SSHFS-Win is the
  # complete runtime requirement.
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

  # `build.rs` reads these and `include_bytes!`s the two MSIs into the
  # executable. The store basenames carry a hash prefix, so copy them under
  # their real names first: those names are also used for the temporary files
  # extracted at install time. Leaving the variables unset keeps a plain
  # `cargo build` working; the runtime then falls back to a `deps/` bundle,
  # `winget` or the download page.
  preConfigure = ''
    installers=$(mktemp -d)
    cp ${winfsp} "$installers/${winfsp.name}"
    cp ${sshfs-win} "$installers/${sshfs-win.name}"

    export WINFSP_INSTALLER="$installers/${winfsp.name}"
    export SSHFS_WIN_INSTALLER="$installers/${sshfs-win.name}"
  '';

  doCheck = false;

  postInstall = ''
    stage=$(mktemp -d)

    # The executable embeds the installers, so the zip is a single file. The
    # executable under `$out/bin` is kept as well.
    cp $out/bin/aidesk-mount-wizard.exe "$stage/aidesk-mount-wizard.exe"

    # Fixed timestamps keep the archive reproducible under SOURCE_DATE_EPOCH.
    TZ=UTC find "$stage" -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +

    mkdir -p $out
    (cd "$stage" && TZ=UTC ${pkgs.zip}/bin/zip -9 -X $out/aidesk-mount-wizard.zip aidesk-mount-wizard.exe)
    rm -rf "$stage"
  '';

  meta = with lib; {
    description = "Windows GUI wizard that maps the AIDesk (nas.chn.moe) workspace as a persistent SSHFS drive";
    longDescription = ''
      Windows x64 executable embedding the pinned WinFsp and SSHFS-Win MSI
      installers: `bin/aidesk-mount-wizard.exe` is also offered as the
      single-file `aidesk-mount-wizard.zip`.
    '';
    license = licenses.mit;
    platforms = platforms.windows;
  };
}
