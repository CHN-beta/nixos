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
mod log;
mod mapping;
mod registry;
mod ui;
mod win32;

/// The AIDesk host. `nas` uses the default sshd port (22), so the SSHFS-Win
/// UNC path needs no `!<port>` suffix.
pub const SERVER: &str = "nas.chn.moe";

fn main() {
    // Snapshot the environment first: the elevated helper re-launches this
    // same executable, so every mode benefits from knowing which binary,
    // pointer width and arguments produced the following lines.
    let args: Vec<String> = std::env::args().collect();
    log::line("===== AIDesk 网盘助手启动 =====");
    log::line(format!("日志文件：{}", log::path().display()));
    log::line(format!("进程指针宽度：{} 位", usize::BITS));
    log::line(format!("操作系统为 64 位：{}", deps::is_os_64bit()));
    log::line(format!(
        "当前程序路径：{}",
        std::env::current_exe()
            .map(|exe| exe.display().to_string())
            .unwrap_or_else(|err| format!("<获取失败：{err}>"))
    ));
    log::line(format!("命令行参数：{args:?}"));
    log::line(format!("管理员权限：{}", win32::is_admin()));

    // Elevated helper modes: write or remove the WinFsp service keepalive
    // configuration, report the result, then exit. The GUI re-launches this
    // same executable with the quiet flags (and waits for it), so no separate
    // helper binary is needed; running the executable manually with the
    // non-quiet flags shows a result dialog.
    match args.get(1).map(String::as_str) {
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
