//! Compiles the Win32 resource script so the executable carries the
//! Common-Controls v6 / DPI-awareness application manifest, and generates the
//! module that embeds the MSI installers passed in by the build.
//!
//! `windres` is invoked directly instead of using `embed-resource` so the same
//! script works for native MSVC builds and for the mingw-w64 cross builds used
//! by nixpkgs (where the tool is prefixed `i686-w64-mingw32-` or
//! `x86_64-w64-mingw32-`).

use std::env;
use std::path::PathBuf;
use std::process::Command;

fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=wizard.rc");
    println!("cargo:rerun-if-changed=wizard.manifest");

    emit_embedded_installers();

    let target = env::var("TARGET").unwrap_or_default();
    if !target.contains("windows") {
        return;
    }

    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR"));
    let out_dir = PathBuf::from(env::var("OUT_DIR").expect("OUT_DIR"));

    let windres = windres_candidates(&target)
        .iter()
        .find(|candidate| {
            Command::new(candidate)
                .arg("--version")
                .output()
                .map(|output| output.status.success())
                .unwrap_or(false)
        })
        .expect("windres not found: add mingw-w64 binutils to the build inputs");

    let object = out_dir.join("mount_wizard_res.o");
    let status = Command::new(windres)
        .arg("-O")
        .arg("coff")
        .arg("--include-dir")
        .arg(&manifest_dir)
        .arg("-i")
        .arg(manifest_dir.join("wizard.rc"))
        .arg("-o")
        .arg(&object)
        .status()
        .expect("failed to spawn windres");

    assert!(status.success(), "windres failed with {status}");
    println!("cargo:rustc-link-arg={}", object.display());
}

/// `windres` executables to try for `target`, most specific first. On a
/// mingw-w64 cross build the tool is prefixed with the target triple; a native
/// MSVC or Linux-mingw build falls back to the unprefixed name.
fn windres_candidates(target: &str) -> &'static [&'static str] {
    if target.contains("i686") {
        &["i686-w64-mingw32-windres", "windres"]
    } else if target.contains("x86_64") {
        &["x86_64-w64-mingw32-windres", "windres"]
    } else {
        &["windres"]
    }
}

/// Writes `embedded_installers.rs` into `OUT_DIR`, defining one
/// `Option<(&'static str, &'static [u8])>` constant per component.
///
/// The Nix derivation exports `WINFSP_INSTALLER`, `SSHFS_WIN_X64_INSTALLER`
/// and `SSHFS_WIN_X86_INSTALLER` pointing at the pinned MSI files, which are
/// then compiled into the executable. A plain developer build leaves the
/// variables unset and gets `None`, so `cargo build` still works without the
/// installers next to the source tree; `src/deps.rs` then falls back to a
/// `deps/` bundle, `winget` or the upstream download page.
fn emit_embedded_installers() {
    let out_dir = PathBuf::from(env::var("OUT_DIR").expect("OUT_DIR"));
    let mut generated = String::new();

    // `SSHFS_WIN_INSTALLER` is the variable name used before x86 and x64
    // installers were embedded separately; it still selects the 64-bit
    // package for builds that have not been updated.
    for (variable, fallback, constant) in [
        ("WINFSP_INSTALLER", None, "WINFSP_INSTALLER"),
        (
            "SSHFS_WIN_X64_INSTALLER",
            Some("SSHFS_WIN_INSTALLER"),
            "SSHFS_WIN_X64_INSTALLER",
        ),
        ("SSHFS_WIN_X86_INSTALLER", None, "SSHFS_WIN_X86_INSTALLER"),
    ] {
        println!("cargo:rerun-if-env-changed={variable}");
        if let Some(fallback) = fallback {
            println!("cargo:rerun-if-env-changed={fallback}");
        }

        let variable = match env::var_os(variable) {
            Some(path) => Some(path),
            None => fallback.and_then(env::var_os),
        };
        let Some(path) = variable else {
            generated.push_str(&format!(
                "pub const {constant}: Option<EmbeddedInstaller> = None;\n"
            ));
            continue;
        };

        let path = PathBuf::from(path);
        println!("cargo:rerun-if-changed={}", path.display());
        let display = path.display();
        let file_name = path
            .file_name()
            .and_then(|name| name.to_str())
            .unwrap_or_else(|| panic!("{constant} has no UTF-8 file name: {display}"));
        let path = path
            .to_str()
            .unwrap_or_else(|| panic!("{constant} is not valid UTF-8: {display}"));
        generated.push_str(&format!(
            "pub const {constant}: Option<EmbeddedInstaller> = \
             Some(({file_name:?}, include_bytes!({path:?})));\n"
        ));
    }

    let path = out_dir.join("embedded_installers.rs");
    std::fs::write(&path, generated)
        .unwrap_or_else(|err| panic!("failed to write {}: {err}", path.display()));
}
