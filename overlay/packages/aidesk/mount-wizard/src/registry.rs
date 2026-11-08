//! WinFsp / SSHFS-Win service registration.
//!
//! SSHFS-Win installs its WinFsp service under the 32-bit registry view:
//! `HKLM\SOFTWARE\WOW6432Node\WinFsp\Services\sshfs`. The installer creates
//!
//! ```text
//! Executable  = C:\Program Files\SSHFS-Win\bin\sshfs-win.exe
//! CommandLine = svc %1 %2 %U
//! Credentials = 1
//! ```
//!
//! Extra tokens appended to `CommandLine` are forwarded to `sshfs` as its own
//! arguments (`sshfs-win.c` calls `concat_argv(sshfs_argv, argv + 4)`), which
//! is how the keepalive options are injected. `Credentials = 1` makes the
//! WinFsp network provider request the password and hand it to the file system
//! on stdin, which is what allows the password to be recalled from the Windows
//! Credential Manager on every reconnect.

use winsafe::{co, HKEY, RegistryValue};

pub const WINFSP_KEY: &str = r"SOFTWARE\WinFsp";
pub const SSHFS_SERVICE_KEY: &str = r"SOFTWARE\WinFsp\Services\sshfs";

/// Passed through to `sshfs`: reconnect on drop and detect dead peers quickly.
pub const KEEPALIVE_OPTIONS: &str =
    "-o ServerAliveInterval=15,ServerAliveCountMax=3,reconnect";

/// Marker used to decide whether the options were already appended.
const KEEPALIVE_MARKER: &str = "ServerAliveInterval";

#[derive(Debug)]
pub enum ConfigureOutcome {
    /// The registry was updated by this process.
    Applied,
    /// The registry already contained the wanted configuration.
    AlreadyApplied,
    /// The current process is not elevated; the caller must retry via
    /// `--apply-registry` under `ShellExecuteW("runas")`.
    NeedsElevation,
    /// Anything else, with a user-facing message.
    Failed(String),
}

/// `true` when the key exists in either registry view.
pub fn key_exists(path: &str) -> bool {
    let exists = |view: co::KEY| {
        HKEY::LOCAL_MACHINE
            .RegOpenKeyEx(
                Some(path),
                co::REG_OPTION::default(),
                co::KEY::READ | view,
            )
            .is_ok()
    };
    exists(co::KEY::WOW64_32KEY) || exists(co::KEY::WOW64_64KEY)
}

/// Reads `HKLM\SOFTWARE\WOW6432Node\WinFsp\Services\sshfs\CommandLine`.
fn command_line() -> Option<String> {
    match HKEY::LOCAL_MACHINE.RegGetValue(
        Some(SSHFS_SERVICE_KEY),
        Some("CommandLine"),
        co::RRF::RT_ANY | co::RRF::SUBKEY_WOW6432KEY,
    ) {
        Ok(RegistryValue::Sz(text)) | Ok(RegistryValue::ExpandSz(text)) => Some(text),
        _ => None,
    }
}

fn credentials_enabled() -> bool {
    match HKEY::LOCAL_MACHINE.RegGetValue(
        Some(SSHFS_SERVICE_KEY),
        Some("Credentials"),
        co::RRF::RT_ANY | co::RRF::SUBKEY_WOW6432KEY,
    ) {
        Ok(RegistryValue::Dword(value)) => value != 0,
        _ => false,
    }
}

/// `true` when both the keepalive flags and the credential passthrough are in
/// place, i.e. nothing needs to be written.
pub fn keepalive_configured() -> bool {
    command_line().is_some_and(|line| line.contains(KEEPALIVE_MARKER)) && credentials_enabled()
}

/// Writes the keepalive options and `Credentials` into the SSHFS-Win service
/// key. Idempotent: repeated calls leave an up-to-date value untouched.
pub fn configure_keepalive() -> ConfigureOutcome {
    match configure_keepalive_inner() {
        Ok(true) => ConfigureOutcome::Applied,
        Ok(false) => ConfigureOutcome::AlreadyApplied,
        Err(err) if err == co::ERROR::ACCESS_DENIED => ConfigureOutcome::NeedsElevation,
        Err(err) if err == co::ERROR::FILE_NOT_FOUND => ConfigureOutcome::Failed(
            "未找到 SSHFS-Win 的服务注册表项，请先安装 SSHFS-Win。".to_owned(),
        ),
        Err(err) => ConfigureOutcome::Failed(format!("写入 WinFsp 服务配置失败：{err}")),
    }
}

fn configure_keepalive_inner() -> Result<bool, co::ERROR> {
    let hkey = HKEY::LOCAL_MACHINE.RegOpenKeyEx(
        Some(SSHFS_SERVICE_KEY),
        co::REG_OPTION::default(),
        co::KEY::READ | co::KEY::WRITE | co::KEY::WOW64_32KEY,
    )?;

    let mut changed = false;

    let current = match hkey.RegGetValue(None, Some("CommandLine"), co::RRF::RT_ANY) {
        Ok(RegistryValue::Sz(text)) | Ok(RegistryValue::ExpandSz(text)) => text,
        _ => String::new(),
    };

    if !current.contains(KEEPALIVE_MARKER) {
        let trimmed = current.trim_end();
        let separator = if trimmed.is_empty() { "" } else { " " };
        let updated = format!("{trimmed}{separator}{KEEPALIVE_OPTIONS}");
        hkey.RegSetValueEx(Some("CommandLine"), RegistryValue::Sz(updated))?;
        changed = true;
    }

    if !credentials_enabled() {
        hkey.RegSetValueEx(Some("Credentials"), RegistryValue::Dword(1))?;
        changed = true;
    }

    Ok(changed)
}

/// Re-launches this executable elevated to perform the registry write.
///
/// When the process is already elevated the write could not be an access-right
/// problem, so there is nothing useful to elevate again.
pub fn request_elevated_configure() -> Result<(), String> {
    if crate::win32::is_admin() {
        return Err("当前已具有管理员权限，但注册表仍然拒绝写入。".to_owned());
    }
    let exe = std::env::current_exe().map_err(|err| format!("无法定位程序路径：{err}"))?;
    crate::win32::shell_execute("runas", &exe.to_string_lossy(), "--apply-registry")
}

/// Entry point of the elevated helper mode (`--apply-registry`).
pub fn elevated_configure() -> i32 {
    match configure_keepalive() {
        ConfigureOutcome::Applied | ConfigureOutcome::AlreadyApplied => {
            crate::win32::info_box("断线自动重连参数已写入 WinFsp 的 SSHFS 服务配置。");
            0
        }
        ConfigureOutcome::NeedsElevation => {
            crate::win32::error_box("仍然没有写入注册表的权限，请以管理员身份运行本向导。");
            1
        }
        ConfigureOutcome::Failed(message) => {
            crate::win32::error_box(&message);
            1
        }
    }
}
