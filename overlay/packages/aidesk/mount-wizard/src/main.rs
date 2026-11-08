//! AIDesk mount wizard: maps the AIDesk (nas.chn.moe) remote home directory as
//! a persistent Windows network drive.
//!
//! The GUI is a two-page `winsafe` wizard (welcome page plus a four-row setup
//! table with a modal account dialog). All long-lived work (dependency checks,
//! installers, registry writes, `WNetAddConnection2W`) lives in the sibling
//! modules; this file only dispatches between the normal GUI mode and the
//! elevated helper modes that the GUI re-launches through
//! `ShellExecuteExW("runas")` when it needs to write `HKLM`.

#![windows_subsystem = "windows"]

mod deps;
mod mapping;
mod registry;
mod ui;
mod win32;

/// The AIDesk host. `nas` uses the default sshd port (22), so the SSHFS-Win
/// UNC path needs no `!<port>` suffix.
pub const SERVER: &str = "nas.chn.moe";

fn main() {
    // Elevated helper modes: write or remove the WinFsp service keepalive
    // configuration, report the result, then exit. The GUI re-launches this
    // same executable with the quiet flags (and waits for it), so no separate
    // helper binary is needed; running the executable manually with the
    // non-quiet flags shows a result dialog.
    match std::env::args().nth(1).as_deref() {
        Some(registry::APPLY_REGISTRY) => {
            std::process::exit(registry::elevated_configure(false));
        }
        Some(registry::APPLY_REGISTRY_QUIET) => {
            std::process::exit(registry::elevated_configure(true));
        }
        Some(registry::UNAPPLY_REGISTRY) => {
            std::process::exit(registry::elevated_unconfigure(false));
        }
        Some(registry::UNAPPLY_REGISTRY_QUIET) => {
            std::process::exit(registry::elevated_unconfigure(true));
        }
        _ => {}
    }

    if let Err(err) = ui::run() {
        win32::error_box(&format!("向导运行失败：{err}"));
    }
}
