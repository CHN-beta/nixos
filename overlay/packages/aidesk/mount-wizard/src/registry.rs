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

use winsafe::{co, guard::RegCloseKeyGuard, HKEY, RegistryValue};

pub const WINFSP_KEY: &str = r"SOFTWARE\WinFsp";
pub const SSHFS_SERVICE_KEY: &str = r"SOFTWARE\WinFsp\Services\sshfs";

/// Passed through to `sshfs`: reconnect on drop and detect dead peers quickly.
pub const KEEPALIVE_OPTIONS: &str =
    "-o ServerAliveInterval=15,ServerAliveCountMax=3,reconnect";

/// Marker used to decide whether the options were already appended.
const KEEPALIVE_MARKER: &str = "ServerAliveInterval";

/// `CommandLine` as shipped by the SSHFS-Win installer, restored when the
/// keepalive options are removed again.
const DEFAULT_COMMAND_LINE: &str = "svc %1 %2 %U";

/// Command-line flag of the elevated helper mode. Running the executable by
/// hand with this flag reports the outcome in a dialog box.
pub const APPLY_REGISTRY: &str = "--apply-registry";

/// Same, without the dialog: this is what the GUI passes, because it waits for
/// the helper to exit and updates its own status label.
pub const APPLY_REGISTRY_QUIET: &str = "--apply-registry-quiet";

/// [`APPLY_REGISTRY`] counterpart that removes the keepalive options again.
pub const UNAPPLY_REGISTRY: &str = "--unapply-registry";

/// [`APPLY_REGISTRY_QUIET`] counterpart that removes the keepalive options.
pub const UNAPPLY_REGISTRY_QUIET: &str = "--unapply-registry-quiet";

#[derive(Debug)]
pub enum ApplyOutcome {
    /// The registry was updated by this process.
    Applied,
    /// The registry already contained the wanted configuration.
    AlreadyApplied,
    /// The current process is not elevated; the caller must retry through the
    /// elevated helper mode under `ShellExecuteW("runas")`.
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
pub fn configure_keepalive() -> ApplyOutcome {
    match configure_keepalive_inner() {
        Ok(true) => ApplyOutcome::Applied,
        Ok(false) => ApplyOutcome::AlreadyApplied,
        Err(err) if err == co::ERROR::ACCESS_DENIED => ApplyOutcome::NeedsElevation,
        Err(err) if err == co::ERROR::FILE_NOT_FOUND => ApplyOutcome::Failed(
            "未找到 SSHFS-Win 的服务注册表项，请先安装 SSHFS-Win。".to_owned(),
        ),
        Err(err) => ApplyOutcome::Failed(format!("写入 WinFsp 服务配置失败：{err}")),
    }
}

fn configure_keepalive_inner() -> Result<bool, co::ERROR> {
    let hkey = open_service_key()?;

    let mut changed = false;

    let current = read_command_line(&hkey);

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

/// Removes the keepalive options from the SSHFS-Win service key, restoring the
/// installer's own `CommandLine`, so [`keepalive_configured`] becomes `false`
/// again. Idempotent: repeated calls leave a clean value untouched.
pub fn unconfigure_keepalive() -> ApplyOutcome {
    match unconfigure_keepalive_inner() {
        Ok(true) => ApplyOutcome::Applied,
        Ok(false) => ApplyOutcome::AlreadyApplied,
        Err(err) if err == co::ERROR::ACCESS_DENIED => ApplyOutcome::NeedsElevation,
        Err(err) if err == co::ERROR::FILE_NOT_FOUND => ApplyOutcome::Failed(
            "未找到 SSHFS-Win 的服务注册表项，请先安装 SSHFS-Win。".to_owned(),
        ),
        Err(err) => ApplyOutcome::Failed(format!("写入 WinFsp 服务配置失败：{err}")),
    }
}

fn unconfigure_keepalive_inner() -> Result<bool, co::ERROR> {
    let hkey = open_service_key()?;

    let current = read_command_line(&hkey);
    if !current.contains(KEEPALIVE_MARKER) {
        return Ok(false);
    }

    hkey.RegSetValueEx(
        Some("CommandLine"),
        RegistryValue::Sz(restore_default_command_line(&current)),
    )?;
    Ok(true)
}

/// Opens the service key for writing (32-bit view, where SSHFS-Win registers
/// itself). The returned guard closes the key when it goes out of scope.
fn open_service_key() -> Result<RegCloseKeyGuard, co::ERROR> {
    HKEY::LOCAL_MACHINE.RegOpenKeyEx(
        Some(SSHFS_SERVICE_KEY),
        co::REG_OPTION::default(),
        co::KEY::READ | co::KEY::WRITE | co::KEY::WOW64_32KEY,
    )
}

fn read_command_line(hkey: &HKEY) -> String {
    match hkey.RegGetValue(None, Some("CommandLine"), co::RRF::RT_ANY) {
        Ok(RegistryValue::Sz(text)) | Ok(RegistryValue::ExpandSz(text)) => text,
        _ => String::new(),
    }
}

/// Drops the injected keepalive options from `current`, leaving the installer's
/// original tokens (and any other custom arguments) in place.
fn restore_default_command_line(current: &str) -> String {
    let stripped = current.replace(KEEPALIVE_OPTIONS, "");
    let tokens: Vec<&str> = stripped.split_whitespace().collect();
    if tokens.is_empty() {
        DEFAULT_COMMAND_LINE.to_owned()
    } else {
        tokens.join(" ")
    }
}

/// Re-launches this executable elevated to perform the registry write and
/// waits for it to finish.
///
/// The wait is what makes the outcome trustworthy: the registry only contains
/// the keepalive options once the elevated helper has actually run, so the
/// caller can report success instead of asking the user to click "重新检查"
/// and hope.
///
/// When the process is already elevated the write could not be an access-right
/// problem, so there is nothing useful to elevate again.
pub fn request_elevated_configure() -> Result<(), String> {
    elevate_registry_helper(APPLY_REGISTRY_QUIET, keepalive_configured, || {
        "管理员助手已退出，但注册表仍未包含断线重连参数。".to_owned()
    })
}

/// [`request_elevated_configure`] counterpart that removes the keepalive
/// options again.
pub fn request_elevated_unconfigure() -> Result<(), String> {
    elevate_registry_helper(
        UNAPPLY_REGISTRY_QUIET,
        || !keepalive_configured(),
        || "管理员助手已退出，但注册表仍包含断线重连参数。".to_owned(),
    )
}

fn elevate_registry_helper(
    flag: &str,
    succeeded: impl Fn() -> bool,
    still_dirty: impl Fn() -> String,
) -> Result<(), String> {
    if crate::win32::is_admin() {
        return Err("当前已具有管理员权限，但注册表仍然拒绝写入。".to_owned());
    }
    let exe = std::env::current_exe().map_err(|err| format!("无法定位程序路径：{err}"))?;
    let exit_code = crate::win32::shell_execute_wait("runas", &exe.to_string_lossy(), flag)?;

    if succeeded() {
        Ok(())
    } else if exit_code == 0 {
        Err(still_dirty())
    } else {
        Err(format!("管理员助手执行失败（退出码 {exit_code}）。"))
    }
}

/// Entry point of the elevated helper mode (`--apply-registry` /
/// `--apply-registry-quiet`). Returns the process exit code: `0` on success.
pub fn elevated_configure(quiet: bool) -> i32 {
    elevated_setup(
        quiet,
        configure_keepalive(),
        "断线自动重连参数已写入 WinFsp 的 SSHFS 服务配置。",
    )
}

/// Entry point of the elevated helper mode (`--unapply-registry` /
/// `--unapply-registry-quiet`). Returns the process exit code: `0` on success.
pub fn elevated_unconfigure(quiet: bool) -> i32 {
    elevated_setup(
        quiet,
        unconfigure_keepalive(),
        "断线自动重连参数已从 WinFsp 的 SSHFS 服务配置中移除。",
    )
}

fn elevated_setup(quiet: bool, outcome: ApplyOutcome, success_message: &str) -> i32 {
    let (code, message) = match outcome {
        ApplyOutcome::Applied | ApplyOutcome::AlreadyApplied => {
            (0, success_message.to_owned())
        }
        ApplyOutcome::NeedsElevation => (
            1,
            "仍然没有写入注册表的权限，请以管理员身份运行本向导。".to_owned(),
        ),
        ApplyOutcome::Failed(message) => (1, message),
    };

    if !quiet {
        if code == 0 {
            crate::win32::info_box(&message);
        } else {
            crate::win32::error_box(&message);
        }
    }

    code
}
