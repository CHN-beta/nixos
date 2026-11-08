//! Detection and installation of the two runtime dependencies.
//!
//! * WinFsp — the user-mode file system driver/framework.
//! * SSHFS-Win — the SSH file system service that plugs into WinFsp.
//!
//! Both are detected through their registry keys (32-bit view, which is where
//! WinFsp/SSHFS-Win register themselves) with a file-system fallback, so an
//! installation that skipped the registry entries is still recognized.

use std::path::PathBuf;

use crate::registry;
use crate::win32;

#[derive(Clone, Copy, Default)]
pub struct Status {
    pub winfsp: bool,
    pub sshfs: bool,
    pub keepalive: bool,
}

impl Status {
    /// Whether mapping can proceed. The keepalive options are desirable but not
    /// required: mapping works without them.
    pub fn ready(&self) -> bool {
        self.winfsp && self.sshfs
    }
}

pub fn check() -> Status {
    Status {
        winfsp: winfsp_installed(),
        sshfs: sshfs_installed(),
        keepalive: registry::keepalive_configured(),
    }
}

fn env_file(variable: &str, relative: &str) -> Option<PathBuf> {
    std::env::var_os(variable).map(|base| PathBuf::from(base).join(relative))
}

fn winfsp_installed() -> bool {
    registry::key_exists(registry::WINFSP_KEY)
        || ["ProgramFiles(x86)", "ProgramFiles", "ProgramW6432"]
            .iter()
            .filter_map(|variable| env_file(variable, r"WinFsp\bin\launcher-x64.exe"))
            .any(|path| path.is_file())
}

fn sshfs_installed() -> bool {
    registry::key_exists(registry::SSHFS_SERVICE_KEY)
        || ["ProgramFiles", "ProgramW6432", "ProgramFiles(x86)"]
            .iter()
            .filter_map(|variable| env_file(variable, r"SSHFS-Win\bin\sshfs.exe"))
            .any(|path| path.is_file())
}

/// Full path of `winget.exe`, resolved through `where` because the Windows
/// Apps execution alias is not a real file next to the other system tools.
fn winget_path() -> Option<String> {
    let output = win32::command("where.exe").arg("winget").output().ok()?;
    if !output.status.success() {
        return None;
    }
    String::from_utf8_lossy(&output.stdout)
        .lines()
        .map(str::trim)
        .find(|line| !line.is_empty())
        .map(str::to_owned)
}

fn open_download_page(url: &str) {
    if let Err(err) = win32::shell_execute("open", url, "") {
        crate::win32::error_box(&format!("无法打开下载页面 {url}：{err}"));
    }
}

/// Installs every missing component. Returns human-readable progress lines.
///
/// With `winget` available the packages are installed through it (elevated,
/// because MSI installers write to Program Files); otherwise the official
/// GitHub release pages are opened so the user can run the MSI manually.
pub fn install_missing(status: &Status) -> Vec<String> {
    if status.winfsp && status.sshfs {
        return vec!["WinFsp 与 SSHFS-Win 均已安装，无需操作。".to_owned()];
    }

    let mut log = Vec::new();

    match winget_path() {
        Some(winget) => {
            let missing = [
                (
                    status.winfsp,
                    "WinFsp.WinFsp",
                    "WinFsp",
                    "https://github.com/winfsp/winfsp/releases/latest",
                ),
                (
                    status.sshfs,
                    "SSHFS-Win.SSHFS-Win",
                    "SSHFS-Win",
                    "https://github.com/winfsp/sshfs-win/releases/latest",
                ),
            ];
            for (installed, package_id, name, url) in missing {
                if installed {
                    continue;
                }
                let parameters = format!(
                    "install --id {package_id} -e --accept-source-agreements --accept-package-agreements"
                );
                match win32::shell_execute("runas", &winget, &parameters) {
                    Ok(()) => log.push(format!(
                        "已启动 {name} 安装（winget）。安装完成后请点击“重新检查”。"
                    )),
                    Err(err) => {
                        log.push(format!(
                            "启动 winget 安装 {name} 失败（{err}），已改为打开官方下载页面。"
                        ));
                        open_download_page(url);
                    }
                }
            }
        }
        None => {
            if !status.winfsp {
                open_download_page("https://github.com/winfsp/winfsp/releases/latest");
            }
            if !status.sshfs {
                open_download_page("https://github.com/winfsp/sshfs-win/releases/latest");
            }
            log.push(
                "未检测到 winget，已打开官方下载页面；请安装 MSI 后点击“重新检查”。".to_owned(),
            );
        }
    }

    log
}
