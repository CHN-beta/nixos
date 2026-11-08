//! Compiles the Win32 resource script so the executable carries the
//! Common-Controls v6 / DPI-awareness application manifest.
//!
//! `windres` is invoked directly instead of using `embed-resource` so the same
//! script works for native MSVC builds and for the mingw-w64 cross build used
//! by nixpkgs (where the tool is prefixed `x86_64-w64-mingw32-`).

use std::env;
use std::path::PathBuf;
use std::process::Command;

fn main() {
    println!("cargo:rerun-if-changed=build.rs");
    println!("cargo:rerun-if-changed=wizard.rc");
    println!("cargo:rerun-if-changed=wizard.manifest");

    let target = env::var("TARGET").unwrap_or_default();
    if !target.contains("windows") {
        return;
    }

    let manifest_dir = PathBuf::from(env::var("CARGO_MANIFEST_DIR").expect("CARGO_MANIFEST_DIR"));
    let out_dir = PathBuf::from(env::var("OUT_DIR").expect("OUT_DIR"));

    let windres = ["x86_64-w64-mingw32-windres", "windres"]
        .into_iter()
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
