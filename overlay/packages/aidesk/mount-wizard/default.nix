{
  lib,
  pkgs,
}:
let
  # One 32-bit executable covers both 32-bit and 64-bit Windows. The MSVCRT
  # flavour is used because the UCRT build (`pkgsCross.ucrt64`) is 64-bit only,
  # and this is the 32-bit toolchain nixpkgs has a binary cache for.
  cross = pkgs.pkgsCross.mingw-msvcrt-i686;

  version = (builtins.fromTOML (builtins.readFile ./Cargo.toml)).package.version;

  # Runtime installers, pinned upstream releases. `build.rs` compiles these
  # into the executable (see `emit_embedded_installers`), so the wizard can
  # install its dependencies offline from a single-file download. WinFsp's MSI
  # already contains both architectures; SSHFS-Win ships separate packages and
  # the wizard picks the one matching the running OS. SSHFS-Win bundles its own
  # `ssh.exe`/`sshfs.exe`, so WinFsp + SSHFS-Win is the complete runtime
  # requirement.
  winfsp = pkgs.fetchurl {
    name = "winfsp-2.1.25156.msi";
    url = "https://github.com/winfsp/winfsp/releases/download/v2.1/winfsp-2.1.25156.msi";
    hash = "sha256-Bzpw4A93Qj40vtmLhuYA3vkzk7pYIiBPrFeikyTbn3o=";
  };

  sshfs-win-x64 = pkgs.fetchurl {
    name = "sshfs-win-3.5.20357-x64.msi";
    url = "https://github.com/winfsp/sshfs-win/releases/download/v3.5.20357/sshfs-win-3.5.20357-x64.msi";
    hash = "sha256-Flfjl/jc4cLS4yIAB/nJ+IJjGIK5vsRgj3g16H3NCWw=";
  };

  sshfs-win-x86 = pkgs.fetchurl {
    name = "sshfs-win-3.5.20357-x86.msi";
    url = "https://github.com/winfsp/sshfs-win/releases/download/v3.5.20357/sshfs-win-3.5.20357-x86.msi";
    hash = "sha256-lkPa8n6344Ta3J5kpCmcjZLmyR4HkT6UJfWxmq07Le0=";
  };

  # The official prebuilt 1.95.0 toolchain from upstream CI, patched by nixpkgs
  # to run on NixOS. This is required because nixpkgs' `rustc` is built from
  # the source tarball, whose version string carries a
  # " (built from a source tarball)" suffix; Rust bakes that string into the
  # crate metadata, which makes the official prebuilt standard library
  # incompatible with it. The prebuilt compiler matches the standard library
  # bit for bit, so no `rustc` or `libstd` has to be built from source.
  rustc = pkgs.rust.packages.prebuilt.rustc;
  cargo = pkgs.rust.packages.prebuilt.cargo;

  # Rust's official prebuilt standard library for the 32-bit Windows GNU
  # target. nixpkgs only ships the host standard library, and building `rustc`
  # for `i686-w64-mingw32` from source is both slow (no binary cache) and
  # broken: nixpkgs' mingw GCC uses the SJLJ exception model, while Rust's
  # DWARF2 `libstd` references the `_Unwind_*` family. Since the crate is built
  # with `panic = "abort"`, those code paths are unreachable, so inert stubs
  # (see `preConfigure`) bridge the gap.
  #
  # The hash follows the toolchain version; it needs to be refreshed together
  # with the compiler when nixpkgs moves to a new Rust release.
  rustStd = pkgs.fetchurl {
    name = "rust-std-${rustc.version}-i686-pc-windows-gnu.tar.xz";
    url = "https://static.rust-lang.org/dist/rust-std-${rustc.version}-i686-pc-windows-gnu.tar.xz";
    hash = "sha256-Lpj7lPxQBpDX5y4HHOKd2YeQ/1GBY5Y/XILDKvupIx0=";
  };

  # Rust build support that targets the 32-bit mingw-w64 toolchain while using
  # the host (x86_64-linux) `rustc`/`cargo` binaries. Its cargo hooks pass
  # `--target i686-pc-windows-gnu` and configure the cross linker, so no
  # `i686-w64-mingw32-rustc` has to be built.
  rustPlatform = cross.makeRustPlatform {
    inherit cargo rustc;
  };
in
rustPlatform.buildRustPackage {
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

  # `cargo-auditable` prepends a wrapper to cargo; the dependency manifest is
  # irrelevant for a GUI wizard, and the wrapper is best avoided on a target it
  # was not exercised with.
  auditable = false;

  nativeBuildInputs = [
    # `i686-w64-mingw32-gcc` links the executable and compiles the unwinding
    # stubs; the binutils wrapper supplies `i686-w64-mingw32-windres` (embedded
    # manifest) and `i686-w64-mingw32-ar` (stub archive).
    cross.stdenv.cc
    cross.buildPackages.binutils
    pkgs.xz
    pkgs.zip
  ];

  # `build.rs` reads these and `include_bytes!`s the three MSIs into the
  # executable. The store basenames carry a hash prefix, so copy them under
  # their real names first: those names are also used for the temporary files
  # extracted at install time. Leaving the variables unset keeps a plain
  # `cargo build` working; the runtime then falls back to a `deps/` bundle,
  # `winget` or the download page.
  #
  # `+crt-static` keeps `libgcc_s_sjlj-1.dll` and `libwinpthread-1.dll` out of
  # the import table (Rust's Windows GNU targets default to the dynamic CRT).
  # Setting it for the target only leaves host build scripts dynamically
  # linked, as they must be.
  env.CARGO_TARGET_I686_PC_WINDOWS_GNU_RUSTFLAGS = "-Ctarget-feature=+crt-static";

  preConfigure = ''
    installers=$(mktemp -d)
    cp ${winfsp} "$installers/${winfsp.name}"
    cp ${sshfs-win-x64} "$installers/${sshfs-win-x64.name}"
    cp ${sshfs-win-x86} "$installers/${sshfs-win-x86.name}"

    export WINFSP_INSTALLER="$installers/${winfsp.name}"
    export SSHFS_WIN_X64_INSTALLER="$installers/${sshfs-win-x64.name}"
    export SSHFS_WIN_X86_INSTALLER="$installers/${sshfs-win-x86.name}"

    # Assemble a writable sysroot: the host standard library (needed by build
    # scripts, which run on the build machine) plus the prebuilt 32-bit Windows
    # standard library.
    host_sysroot="$(${rustc}/bin/rustc --print sysroot)"
    sysroot="$TMPDIR/rustc-sysroot"
    mkdir -p "$sysroot/lib/rustlib"
    for entry in "$host_sysroot"/lib/*; do
      name=$(basename "$entry")
      if [ "$name" != rustlib ]; then
        ln -s "$entry" "$sysroot/lib/$name"
      fi
    done
    for entry in "$host_sysroot"/lib/rustlib/*; do
      name=$(basename "$entry")
      if [ "$name" != i686-pc-windows-gnu ]; then
        ln -s "$entry" "$sysroot/lib/rustlib/$name"
      fi
    done
    tar -xJf ${rustStd} -C "$TMPDIR"
    cp -r "$TMPDIR"/rust-std-*/rust-std-i686-pc-windows-gnu/lib/rustlib/i686-pc-windows-gnu \
      "$sysroot/lib/rustlib/"

    # Rust's DWARF2 `libstd` references `_Unwind_*`, which the SJLJ-based
    # nixpkgs mingw GCC does not provide. `panic = "abort"` guarantees these
    # are never called, so empty definitions are enough. The archive is named
    # `libgcc_eh.a` and placed on the native library search path so the linker
    # resolves `-lgcc_eh` from it instead of GCC's SJLJ archive.
    cat > "$TMPDIR/eh_stub.c" <<'EOF'
    /* Inert unwinding entry points; panic = "abort" never unwinds. */
    typedef unsigned int uw_word;

    void _Unwind_Resume(void) {}
    void _Unwind_RaiseException(void) {}
    void _Unwind_DeleteException(void) {}
    uw_word _Unwind_GetIP(void) { return 0; }
    uw_word _Unwind_GetIPInfo(int *before) { if (before) *before = 0; return 0; }
    void *_Unwind_GetLanguageSpecificData(void) { return 0; }
    uw_word _Unwind_GetRegionStart(void) { return 0; }
    uw_word _Unwind_GetTextRelBase(void) { return 0; }
    uw_word _Unwind_GetDataRelBase(void) { return 0; }
    void *_Unwind_FindEnclosingFunction(void) { return 0; }
    void _Unwind_SetGR(void) {}
    void _Unwind_SetIP(void) {}
    int _Unwind_Backtrace(void) { return 0; }
    int __gcc_personality_v0(void) { return 0; }
    void __register_frame_info(void) {}
    void __deregister_frame_info(void) {}
EOF
    ${cross.stdenv.cc}/bin/${cross.stdenv.cc.targetPrefix}gcc \
      -c "$TMPDIR/eh_stub.c" -o "$TMPDIR/eh_stub.o"
    ${cross.buildPackages.binutils}/bin/${cross.buildPackages.binutils.targetPrefix}ar \
      rcs "$TMPDIR/libgcc_eh.a" "$TMPDIR/eh_stub.o"

    # Wrap rustc so every invocation (target and build scripts) sees the merged
    # sysroot and the stub library directory.
    cat > "$TMPDIR/rustc" <<EOF
#!${pkgs.runtimeShell}
exec ${rustc}/bin/rustc --sysroot "$sysroot" -Lnative="$TMPDIR" "\$@"
EOF
    chmod +x "$TMPDIR/rustc"
    export RUSTC="$TMPDIR/rustc"
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

    # Static download layout for the public SPA: nginx serves
    # https://aidesk.chn.moe/downloads/ directly from this output (see
    # nixosConfigurations/vps6). The bare files at the output root stay for
    # anyone consuming the package itself.
    mkdir -p $out/downloads
    cp $out/aidesk-mount-wizard.zip $out/downloads/aidesk-mount-wizard.zip
    cp $out/bin/aidesk-mount-wizard.exe $out/downloads/aidesk-mount-wizard.exe
  '';

  meta = with lib; {
    description = "32-bit Windows GUI wizard that maps the AIDesk (nas.chn.moe) workspace as a persistent SSHFS drive";
    longDescription = ''
      Windows executable (PE32, runs on both 32-bit and 64-bit Windows) that
      embeds the pinned WinFsp MSI and both the 64-bit and 32-bit SSHFS-Win
      MSIs: `bin/aidesk-mount-wizard.exe` is also offered as the single-file
      `aidesk-mount-wizard.zip`. The wizard installs the matching SSHFS-Win
      package for the running OS.
    '';
    license = licenses.mit;
    platforms = platforms.windows;
  };
}
