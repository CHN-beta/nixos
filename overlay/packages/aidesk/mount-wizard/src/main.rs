//! AIDesk mount wizard: maps the AIDesk (nas.chn.moe) remote home directory as
//! a persistent Windows network drive.
//!
//! The wizard is a four-page `winsafe` GUI. All long-lived work (dependency
//! checks, registry writes, `WNetAddConnection2W`) lives in the sibling
//! modules; this file only dispatches between the normal GUI mode and the
//! elevated helper mode that the GUI re-launches through `ShellExecuteW`
//! (`runas`) when it needs to write `HKLM`.

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
    // Elevated helper mode: write the WinFsp service keepalive configuration,
    // report the result, then exit. The GUI re-launches this same executable
    // with this flag, so no separate helper binary is needed.
    if std::env::args().nth(1).as_deref() == Some("--apply-registry") {
        std::process::exit(registry::elevated_configure());
    }

    if let Err(err) = ui::run() {
        win32::error_box(&format!("向导运行失败：{err}"));
    }
}
