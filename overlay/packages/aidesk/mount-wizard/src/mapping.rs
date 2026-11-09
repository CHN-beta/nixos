//! Drive mapping, detection and credential persistence.
//!
//! Two Win32 facts shape this module:
//!
//! * `WNetAddConnection2W` (mpr.dll) is the same code path `net use` uses.
//!   With `CONNECT_UPDATE_PROFILE` the mapping is remembered and re-created at
//!   the next logon. `CONNECT_CMD_SAVECRED` is deliberately *not* used: MPR
//!   turns it into a `CRED_TYPE_DOMAIN_PASSWORD` entry, which Windows rejects
//!   for a target containing `@` (`\\sshfs\<user>@nas.chn.moe`).
//! * The WinFsp network provider (WinFsp.Np) looks the password up in the
//!   Windows Credential Manager — `CredReadW(lpRemoteName, CRED_TYPE_GENERIC)`
//!   in `src/dll/np.c` — whenever no password is passed inline, and hands it to
//!   the file system service. That is what makes the mapping reconnect
//!   unattended.
//!
//! Therefore the password is written with `CredWriteW` as a *generic*
//! credential whose target is the UNC path, and the connection is then
//! established without inline credentials. `cmdkey.exe` cannot be used for
//! this: `/add:` creates a domain-password credential, which fails on `@`
//! targets, and `/generic:` writes a credential that WinFsp.Np rejects because
//! it does not end the blob with a `L'\0'` `WCHAR`.
//!
//! Passing the password inline stays as a fallback for machines where the
//! credential store is not reachable.
//!
//! A 32-bit WOW64 process on 64-bit Windows cannot use the MPR path above. The
//! `ProviderPath` under
//! `HKLM\SYSTEM\CurrentControlSet\Services\WinFsp.Np\NetworkProvider` points at
//! the 64-bit `winfsp-x64.dll` (the MSI self-registers that DLL on AMD64, and
//! `FspNpRegister` writes the registering module's own path). `HKLM\SYSTEM` is
//! not WOW64-redirected, so the 32-bit `mpr.dll` sees that same 64-bit path,
//! fails to load it and silently skips WinFsp.Np; the request then falls
//! through to `LanmanWorkstation`, which burns the NetBIOS timeout and returns
//! `ERROR_BAD_NETPATH` (53). Such a process therefore shells out to the native
//! 64-bit `%SystemRoot%\Sysnative\net.exe` instead, which loads the 64-bit
//! `mpr.dll` and reaches WinFsp.Np. The generic credential written above is
//! shared through `lsass.exe`, so the no-password `net use` still finds it.
//!
//! [`detect_mounted_drive`] and [`unmap_drive`] are the reverse direction: they
//! report whether one of our drives is mapped right now and disconnect it,
//! removing the saved password along with the connection.
//!
//! The name Explorer shows in "This PC" is a third, independent concern. It is
//! not the WinFsp volume label (`-o volname=`, which [`registry`] could append
//! to the machine-wide service `CommandLine`, and which only feeds
//! `GetVolumeInformation`): Explorer names network drives itself and resolves
//! the name through
//! `HKCU\Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2\<share>`.
//! Writing the same `_LabelFromReg` string value that Explorer's "Rename"
//! writes makes the drive show up as `AIDesk(<user>)` (`<user>` is the SSH
//! account). The value is per-user, needs no elevation, is keyed by the share
//! instead of the drive letter, and therefore survives both a letter change and
//! the reconnect at logon. [`set_drive_label`] seeds it before connecting so
//! Explorer already sees it when the drive first appears, and [`unmap_drive`]
//! removes it again when it still holds the value this wizard wrote.
//!
//! [`registry`]: crate::registry

use std::path::PathBuf;
use std::process::Stdio;
use std::time::Duration;

use winsafe::{co, HKEY, RegistryValue};

use crate::{deps, win32, SERVER};

const RESOURCETYPE_DISK: u32 = 0x0000_0001;
const CONNECT_UPDATE_PROFILE: u32 = 0x0000_0001;

/// `CRED_TYPE_GENERIC`: the type WinFsp.Np reads.
const CRED_TYPE_GENERIC: u32 = 0x0000_0001;

/// `CRED_PERSIST_ENTERPRISE`: roams with the profile of domain users and stays
/// local for everybody else.
const CRED_PERSIST_ENTERPRISE: u32 = 0x0000_0003;

/// `CP_OEMCP`: the console code page `net.exe` writes its messages in.
const CP_OEMCP: u32 = 1;

/// `ERROR_ALREADY_ASSIGNED`: the drive letter is still held by the mapping we
/// just cancelled.
const ERROR_ALREADY_ASSIGNED: u32 = 85;

/// `ERROR_NOT_CONNECTED`: the drive letter holds no network connection.
const ERROR_NOT_CONNECTED: u32 = 2250;

/// Length of the buffer `WNetGetConnectionW` fills with the UNC path.
const REMOTE_NAME_LEN: usize = 512;

/// Explorer's per-mount-point settings, keyed by the UNC share path with every
/// `\` replaced by `#` (`\\sshfs\<user>@nas.chn.moe` becomes
/// `##sshfs#<user>@nas.chn.moe`). This is where Explorer's "Rename" stores the
/// display name of a mapped network drive.
const MOUNT_POINTS2_KEY: &str =
    r"Software\Microsoft\Windows\CurrentVersion\Explorer\MountPoints2";

/// The string value Explorer reads as the custom name of a network drive.
const LABEL_VALUE: &str = "_LabelFromReg";

#[repr(C)]
struct NetResourceW {
    scope: u32,
    resource_type: u32,
    display_type: u32,
    usage: u32,
    local_name: *const u16,
    remote_name: *const u16,
    comment: *const u16,
    provider: *const u16,
}

/// `CREDENTIALW`. `LAST_WRITTEN` is a `FILETIME`, i.e. two `DWORD`s; spelling
/// it as `u64` would change the struct layout on 32-bit Windows (where `u64`
/// is 8-byte aligned, while the Win32 struct only needs 4-byte alignment).
#[repr(C)]
struct CredentialW {
    flags: u32,
    cred_type: u32,
    target_name: *const u16,
    comment: *const u16,
    last_written: [u32; 2],
    credential_blob_size: u32,
    credential_blob: *const u8,
    persist: u32,
    attribute_count: u32,
    attributes: *const std::ffi::c_void,
    target_alias: *const u16,
    user_name: *const u16,
}

/// `CREDENTIALW` is exactly 52 bytes on 32-bit Windows; a field with stricter
/// alignment than the Win32 struct would silently change it.
#[cfg(target_pointer_width = "32")]
const _: () = assert!(std::mem::size_of::<CredentialW>() == 52);

#[link(name = "mpr")]
extern "system" {
    fn WNetAddConnection2W(
        resource: *const NetResourceW,
        password: *const u16,
        username: *const u16,
        flags: u32,
    ) -> u32;

    fn WNetCancelConnection2W(name: *const u16, flags: u32, force: i32) -> u32;

    fn WNetGetConnectionW(local_name: *const u16, remote_name: *mut u16, length: *mut u32) -> u32;

    fn WNetGetLastErrorW(
        error: *mut u32,
        error_buf: *mut u16,
        error_buf_size: u32,
        name_buf: *mut u16,
        name_buf_size: u32,
    ) -> u32;
}

#[link(name = "advapi32")]
extern "system" {
    fn CredWriteW(credential: *const CredentialW, flags: u32) -> i32;

    fn CredDeleteW(target_name: *const u16, cred_type: u32, flags: u32) -> i32;

    fn CredEnumerateW(
        filter: *const u16,
        flags: u32,
        count: *mut u32,
        credentials: *mut *mut *const CredentialW,
    ) -> i32;

    fn CredFree(buffer: *mut std::ffi::c_void);
}

#[link(name = "kernel32")]
extern "system" {
    fn QueryDosDeviceW(device_name: *const u16, target_path: *mut u16, max: u32) -> u32;

    fn MultiByteToWideChar(
        code_page: u32,
        flags: u32,
        multi_byte_str: *const u8,
        cb_multi_byte: i32,
        wide_char_str: *mut u16,
        cch_wide_char: i32,
    ) -> i32;
}

pub struct MapOutcome {
    pub ok: bool,
    pub log: Vec<String>,
}

/// Maps `\\sshfs\<username>@nas.chn.moe` onto `drive` (e.g. `"Z:"`).
pub fn map_drive(drive: &str, username: &str, password: &str) -> MapOutcome {
    let mut log = Vec::new();

    let unc = format!(r"\\sshfs\{username}@{SERVER}");
    let drive_root = format!("{drive}\\");

    // The password is never written to the log; only its length is, which is
    // enough to tell a mistyped/empty password from a Windows error.
    crate::log::line("===== 开始挂载网盘 =====");
    crate::log::line(format!(
        "map_drive(drive={drive:?}, username={username:?}, password_len={})，unc={unc:?}",
        password.len()
    ));

    log.push(format!("目标盘符：{drive}"));
    log.push(format!("远程路径：{unc}（远程主目录）"));

    // Seed the Explorer name before connecting. The shell may paint the new
    // drive as soon as the connection is reported, so the value has to be in
    // place before that: reading it is what turns the UNC path into
    // `AIDesk(<user>)`. A failure here is not fatal — the drive is usable
    // without a custom name — and is reported by the write after the mount.
    match set_drive_label(username) {
        Ok(()) => crate::log::line(format!(
            "set_drive_label 预写成功：{}",
            drive_label(username)
        )),
        Err(err) => crate::log::line(format!("set_drive_label 预写失败：{err}")),
    }

    // Store the password as a generic credential keyed by the UNC path; this
    // is exactly what WinFsp.Np reads when it needs the password. The
    // credential must exist before the connection is attempted, because the
    // connection below passes no password at all.
    let credential_saved = match remember_credential(&unc, username, password) {
        Ok(()) => {
            crate::log::line("remember_credential：密码已保存到 Windows 凭据管理器。");
            log.push("密码已保存到 Windows 凭据管理器。".to_owned());
            true
        }
        Err(err) => {
            crate::log::line(format!("remember_credential 失败：{err}"));
            log.push(format!("保存密码到 Windows 凭据管理器失败：{err}"));
            false
        }
    };

    log.push("正在建立 SSH 连接（首次连接可能需要数秒）……".to_owned());
    crate::log::line("正在建立 SSH 连接（首次连接可能需要数秒）……");

    let connect_result = if needs_native_net() {
        crate::log::line(format!(
            "进程为 32 位而系统为 64 位（WOW64），改用原生 64 位 net.exe：{}",
            native_net_exe().display()
        ));
        log.push(
            "检测到 64 位 Windows 上的 32 位进程，改用系统原生 64 位网络提供程序挂载。"
                .to_owned(),
        );
        connect_native_net(drive, &unc, username, password, credential_saved, &mut log)
    } else {
        connect_mpr(drive, &unc, username, password, credential_saved, &mut log)
    };

    if let Err(err) = connect_result {
        crate::log::line(format!("map_drive 失败：{err}"));
        log_sshfs_binaries();
        log.push(format!("映射失败：{err}"));
        log.push("请确认 WinFsp 与 SSHFS-Win 已安装，且用户名、密码正确。".to_owned());
        log.push(log_file_line());
        return MapOutcome { ok: false, log };
    }

    let drive_type = winsafe::GetDriveType(Some(&drive_root));
    crate::log::line(format!("GetDriveType({drive_root:?}) 返回 {drive_type}"));
    if matches!(drive_type, winsafe::co::DRIVE::REMOTE) {
        log.push(format!("映射成功：{drive} 已就绪。"));
    } else {
        log.push(format!(
            "已建立映射；{drive} 可能还需要几秒建立 SSH 连接。"
        ));
    }
    if credential_saved {
        log.push("登录 Windows 时会使用保存的密码自动重连。".to_owned());
    } else {
        log.push("密码未能保存，下次登录可能需要手动重新映射。".to_owned());
    }

    // Assert the Explorer name once more now that the mapping exists: the shell
    // can create or refresh the MountPoints2 subkey while it handles the new
    // connection, racing with the pre-seeded value. The write is idempotent, so
    // this is a no-op when the pre-seeded value survived.
    match set_drive_label(username) {
        Ok(()) => {
            crate::log::line(format!(
                "set_drive_label 后写成功：{}",
                drive_label(username)
            ));
            log.push(format!("「此电脑」中显示为 {}。", drive_label(username)));
        }
        Err(err) => {
            crate::log::line(format!("set_drive_label 后写失败：{err}"));
            log.push(format!("设置网盘显示名称失败：{err}"));
        }
    }

    crate::log::line("===== 挂载完成 =====");

    log.push(log_file_line());
    MapOutcome { ok: true, log }
}

/// One `MapOutcome.log` entry telling the user where the log file is.
fn log_file_line() -> String {
    format!("日志文件：{}", crate::log::path().display())
}

/// Probes the SSHFS-Win executables when the mapping failed. Error 53
/// (`ERROR_BAD_NETPATH`) means no provider accepted the name: either the
/// network provider could not start `sshfs-win.exe`, or — the WOW64 case fixed
/// in [`connect_native_net`] — 32-bit MPR could not load the 64-bit WinFsp.Np.
/// The actual executable location therefore matters.
fn log_sshfs_binaries() {
    for variable in ["ProgramFiles", "ProgramW6432", "ProgramFiles(x86)"] {
        match std::env::var_os(variable) {
            Some(base) => {
                let base = std::path::PathBuf::from(base);
                for relative in [r"SSHFS-Win\bin\sshfs-win.exe", r"SSHFS-Win\bin\sshfs.exe"] {
                    let path = base.join(relative);
                    crate::log::line(format!(
                        "SSHFS-Win 探测 %{variable}%\\{relative} = {}（{}）",
                        path.display(),
                        if path.is_file() { "存在" } else { "不存在" }
                    ));
                }
            }
            None => crate::log::line(format!("SSHFS-Win 探测：环境变量 {variable} 未设置")),
        }
    }
}

/// Whether connections must go through the native 64-bit `net.exe`.
///
/// Only the WOW64 case is affected. On a 32-bit OS the registered provider is
/// `winfsp-x86.dll`, which 32-bit MPR can load; on a 64-bit OS a 64-bit process
/// loads the 64-bit `mpr.dll`, which can load `winfsp-x64.dll`. Only a 32-bit
/// process on a 64-bit OS sees the 64-bit `ProviderPath` through
/// `HKLM\SYSTEM` and cannot load it.
fn needs_native_net() -> bool {
    usize::BITS == 32 && deps::is_os_64bit()
}

/// `%SystemRoot%\Sysnative\net.exe`: the native 64-bit `net.exe` as reachable
/// from a WOW64 process. `Sysnative` is a virtual alias that bypasses the
/// `System32` -> `SysWOW64` redirection for 32-bit callers.
fn native_net_exe() -> PathBuf {
    std::env::var_os("SystemRoot")
        .map(PathBuf::from)
        .unwrap_or_else(|| PathBuf::from(r"C:\Windows"))
        .join(r"Sysnative\net.exe")
}

/// Result of one `net.exe` invocation.
struct NetOutput {
    code: u32,
    stdout: String,
    stderr: String,
}

/// Runs the native `net.exe` with `args` and logs the exit code and output.
///
/// `stdin` is closed: without an inline password `net.exe` prompts for one
/// when WinFsp.Np's credential lookup misses, and the invisible prompt would
/// block the GUI forever. `description` is the sanitized command line shown in
/// the log; the password itself must never appear in it.
fn run_net(args: &[&str], description: &str) -> Result<NetOutput, String> {
    let exe = native_net_exe();
    let output = win32::command(&exe)
        .args(args)
        .stdin(Stdio::null())
        .stdout(Stdio::piped())
        .stderr(Stdio::piped())
        .output()
        .map_err(|err| format!("无法运行 {}：{err}", exe.display()))?;

    let code = output.status.code().unwrap_or(1);
    let stdout = decode_oem(&output.stdout);
    let stderr = decode_oem(&output.stderr);
    crate::log::line(format!(
        "net.exe {description} => 退出码={code}，stdout={stdout:?}，stderr={stderr:?}"
    ));

    Ok(NetOutput {
        code: code.max(0) as u32,
        stdout,
        stderr,
    })
}

/// Decodes console output: `net.exe` writes its messages in the console OEM
/// code page, not UTF-8.
fn decode_oem(bytes: &[u8]) -> String {
    if bytes.is_empty() {
        return String::new();
    }

    let wide_len = unsafe {
        MultiByteToWideChar(
            CP_OEMCP,
            0,
            bytes.as_ptr(),
            bytes.len() as i32,
            std::ptr::null_mut(),
            0,
        )
    };
    if wide_len <= 0 {
        return String::from_utf8_lossy(bytes).trim_end().to_owned();
    }

    let mut buffer = vec![0u16; wide_len as usize];
    let written = unsafe {
        MultiByteToWideChar(
            CP_OEMCP,
            0,
            bytes.as_ptr(),
            bytes.len() as i32,
            buffer.as_mut_ptr(),
            wide_len,
        )
    };
    let written = written.max(0) as usize;
    String::from_utf16_lossy(&buffer[..written])
        .trim_end_matches(|ch| ch == '\r' || ch == '\n')
        .to_owned()
}

/// Connects `unc` to `drive` through the native 64-bit `net.exe` (WOW64).
///
/// The first attempt passes no password at all, so the 64-bit WinFsp.Np reads
/// the `CRED_TYPE_GENERIC` credential written by [`remember_credential`] and no
/// password ever reaches a command line. Only if that fails is the password
/// passed inline.
fn connect_native_net(
    drive: &str,
    unc: &str,
    username: &str,
    password: &str,
    credential_saved: bool,
    log: &mut Vec<String>,
) -> Result<(), String> {
    // A stale mapping on the same letter makes `net use` fail with
    // ERROR_ALREADY_ASSIGNED; "not connected" is the expected failure.
    match run_net(
        &["use", drive, "/delete", "/y"],
        &format!("use {drive} /delete /y（清理旧连接）"),
    )? {
        NetOutput { code: 0, .. } => log.push(format!("已断开 {drive} 上的旧连接。")),
        NetOutput { code, .. } => crate::log::line(format!(
            "net.exe use {drive} /delete /y 退出码 {code}（盘符可能本就没有连接）"
        )),
    }

    if credential_saved {
        let output = run_net(
            &["use", drive, unc, "/persistent:yes"],
            &format!("use {drive} {unc} /persistent:yes（凭据管理器模式）"),
        )?;
        if output.code == 0 {
            return Ok(());
        }
        log.push(format!(
            "凭据管理器方式未成功（net.exe 退出码 {}），改用密码直连重试。",
            output.code
        ));
    }

    let user_arg = format!("/user:{username}");
    let output = run_net(
        &[
            "use",
            drive,
            unc,
            password,
            &user_arg,
            "/persistent:yes",
        ],
        &format!("use {drive} {unc} <password> {user_arg} /persistent:yes（密码直连模式）"),
    )?;
    if output.code == 0 {
        Ok(())
    } else {
        let detail = if output.stderr.is_empty() {
            output.stdout
        } else {
            output.stderr
        };
        if detail.is_empty() {
            Err(format!("net.exe 退出码 {}", output.code))
        } else {
            Err(format!("net.exe 退出码 {}：{detail}", output.code))
        }
    }
}

/// Establishes the mapping through `WNetAddConnection2W`.
///
/// Used on 32-bit Windows (where `winfsp-x86.dll` is the registered provider)
/// and by any 64-bit process; see [`needs_native_net`] for the WOW64 case this
/// cannot serve.
fn connect_mpr(
    drive: &str,
    unc: &str,
    username: &str,
    password: &str,
    credential_saved: bool,
    log: &mut Vec<String>,
) -> Result<(), String> {
    // A stale mapping on the same letter makes WNetAddConnection2W fail with
    // ERROR_ALREADY_ASSIGNED, so drop it first. "Not connected" is expected.
    let drive_w = win32::wide(drive);
    let cancel_status = unsafe { WNetCancelConnection2W(drive_w.as_ptr(), 0, 1) };
    crate::log::line(format!(
        "WNetCancelConnection2W(drive={drive:?}, flags=0, force=1) 返回 {cancel_status}"
    ));
    if cancel_status == 0 {
        log.push(format!("已断开 {drive} 上的旧连接。"));
    }

    let local_w = win32::wide(drive);
    let remote_w = win32::wide(unc);
    let username_w = win32::wide(username);
    let password_w = win32::wide(password);

    let resource = NetResourceW {
        scope: 0,
        resource_type: RESOURCETYPE_DISK,
        display_type: 0,
        usage: 0,
        local_name: local_w.as_ptr(),
        remote_name: remote_w.as_ptr(),
        comment: std::ptr::null(),
        provider: std::ptr::null(),
    };

    let mut status = 0;
    if credential_saved {
        status = connect_retrying(&resource, std::ptr::null(), std::ptr::null());
        if status != 0 {
            log.push(format!(
                "凭据管理器方式未成功（{}），改用密码直连重试。",
                error_text(status)
            ));
        }
    }

    if !credential_saved || status != 0 {
        // Inline credentials plus `CONNECT_UPDATE_PROFILE`: the mapping is
        // still persisted in the profile, without asking MPR to save a
        // credential of its own.
        status = connect_retrying(&resource, password_w.as_ptr(), username_w.as_ptr());
    }

    if status != 0 {
        return Err(error_text(status));
    }
    Ok(())
}

/// Connects, retrying while the drive letter is still being released by the
/// cancelled mapping (WinFsp stops the previous service asynchronously).
///
/// Every attempt is logged together with its `WNetGetLastErrorW` details, so a
/// log from a failing machine shows the exact MPR error instead of just the
/// numeric return code.
fn connect_retrying(
    resource: &NetResourceW,
    password: *const u16,
    username: *const u16,
) -> u32 {
    let inline = !password.is_null() && !username.is_null();
    let connect =
        || unsafe { WNetAddConnection2W(resource, password, username, CONNECT_UPDATE_PROFILE) };

    let mut attempt = 1;
    let mut status = connect();
    log_connect_attempt(attempt, inline, status);

    for _ in 0..10 {
        if status != ERROR_ALREADY_ASSIGNED {
            break;
        }
        crate::log::line(format!(
            "盘符仍被旧连接占用（错误 {status}），500ms 后重试……"
        ));
        std::thread::sleep(Duration::from_millis(500));
        attempt += 1;
        status = connect();
        log_connect_attempt(attempt, inline, status);
    }
    status
}

/// Logs one `WNetAddConnection2W` call; on failure also the extended error
/// from `WNetGetLastErrorW`, which must be queried immediately afterwards.
fn log_connect_attempt(attempt: u32, inline: bool, status: u32) {
    crate::log::line(format!(
        "WNetAddConnection2W（第 {attempt} 次，inline_credentials={inline}，flags=CONNECT_UPDATE_PROFILE/0x{CONNECT_UPDATE_PROFILE:08x}）返回 {status}：{}",
        error_text(status)
    ));
    if status != 0 {
        log_net_last_error(status);
    }
}

/// Queries `WNetGetLastErrorW` and writes its extended error code, message and
/// provider name to the log.
fn log_net_last_error(fallback_status: u32) {
    let mut error = 0u32;
    let mut error_buf = vec![0u16; 512];
    let mut name_buf = vec![0u16; 256];

    let ret = unsafe {
        WNetGetLastErrorW(
            &mut error,
            error_buf.as_mut_ptr(),
            error_buf.len() as u32,
            name_buf.as_mut_ptr(),
            name_buf.len() as u32,
        )
    };

    crate::log::line(format!(
        "WNetGetLastErrorW 返回 {ret}：扩展错误码={error}，error_buf={:?}，name_buf={:?}（WNetAddConnection2W 返回 {fallback_status}）",
        win32::from_wide(&error_buf),
        win32::from_wide(&name_buf),
    ));
}

/// Writes the password as a `CRED_TYPE_GENERIC` credential for `target`.
///
/// The blob is a UTF-16LE string *including* its terminating NUL `WCHAR`:
/// WinFsp.Np (`NPAddConnection` in `src/dll/np.c`) rejects any credential whose
/// last `WCHAR` is not `L'\0'`, so `credential_blob_size` must be
/// `password_w.len() * 2` rather than `password_w.len() * 2 - 2`.
fn remember_credential(target: &str, username: &str, password: &str) -> Result<(), String> {
    let target_w = win32::wide(target);
    let username_w = win32::wide(username);
    let password_w = win32::wide(password);

    let credential = CredentialW {
        flags: 0,
        cred_type: CRED_TYPE_GENERIC,
        target_name: target_w.as_ptr(),
        comment: std::ptr::null(),
        last_written: [0, 0],
        credential_blob_size: (password_w.len() * std::mem::size_of::<u16>()) as u32,
        credential_blob: password_w.as_ptr().cast::<u8>(),
        persist: CRED_PERSIST_ENTERPRISE,
        attribute_count: 0,
        attributes: std::ptr::null(),
        target_alias: std::ptr::null(),
        user_name: username_w.as_ptr(),
    };

    let ret = unsafe { CredWriteW(&credential, 0) };
    let last_error = std::io::Error::last_os_error();
    crate::log::line(format!(
        "CredWriteW(target={target:?}, username={username:?}, password_len={}) 返回 {ret}，last_os_error={last_error}",
        password.len()
    ));

    if ret != 0 {
        Ok(())
    } else {
        Err(format!("CredWriteW 失败：{last_error}"))
    }
}

/// Drive letter of the SSHFS mapping to the AIDesk server, e.g. `"Z:"`.
///
/// Every letter is probed: `WNetGetConnectionW` (or, when MPR cannot reach the
/// provider, `QueryDosDeviceW`) reports the UNC path of an active network
/// connection, while `HKCU\Network\<Letter>` keeps the paths of persistent
/// mappings even when the connection is momentarily down (right after logon, or
/// after a dropped link). All of them are matched against
/// `\\sshfs\<user>@nas.chn.moe`, case-insensitively.
pub fn detect_mounted_drive() -> Option<String> {
    ('A'..='Z').find_map(|letter| {
        let remote = active_connection(letter).or_else(|| saved_connection(letter))?;
        is_sshfs_target(&remote).then(|| format!("{letter}:"))
    })
}

/// `true` for `\\sshfs\<user>@nas.chn.moe`, in any case.
fn is_sshfs_target(remote: &str) -> bool {
    sshfs_username(remote).is_some()
}

/// SSH account embedded in `\\sshfs\<user>@nas.chn.moe`, if `remote` is one of
/// our shares.
///
/// The comparison is case-insensitive because both `WNetGetConnectionW` and
/// `HKCU\Network` may hand back the path in a different case, while the user
/// name is sliced out of the original string to preserve its case in the
/// label.
fn sshfs_username(remote: &str) -> Option<&str> {
    let lower = remote.to_ascii_lowercase();
    let prefix = r"\\sshfs\";
    let suffix = format!("@{}", SERVER.to_ascii_lowercase());
    if lower.len() < prefix.len() + suffix.len()
        || !lower.starts_with(prefix)
        || !lower.ends_with(&suffix)
    {
        return None;
    }
    Some(&remote[prefix.len()..remote.len() - suffix.len()])
}

/// Name Explorer shows for the mapped drive, e.g. `AIDesk(straycat)`.
fn drive_label(username: &str) -> String {
    format!("AIDesk({username})")
}

/// `MountPoints2` subkey of the share at `unc`.
///
/// Explorer encodes the UNC path by replacing every backslash with `#`, so
/// `\\sshfs\<user>@nas.chn.moe` becomes `##sshfs#<user>@nas.chn.moe`.
fn mount_points_key(unc: &str) -> String {
    format!(r"{}\{}", MOUNT_POINTS2_KEY, unc.replace('\\', "#"))
}

/// Writes `_LabelFromReg = AIDesk(<username>)` for the share.
///
/// This is the value Explorer's "Rename" writes, and it lives under `HKCU`, so
/// no elevation is needed and it is restored with the user's profile. Writing
/// it before the drive is connected lets Explorer use it on the very first
/// enumeration. Idempotent: an already correct value is left untouched.
fn set_drive_label(username: &str) -> Result<(), String> {
    let label = drive_label(username);
    let key = mount_points_key(&format!(r"\\sshfs\{username}@{SERVER}"));

    if matches!(
        HKEY::CURRENT_USER.RegGetValue(Some(&key), Some(LABEL_VALUE), co::RRF::RT_ANY),
        Ok(RegistryValue::Sz(text)) if text == label
    ) {
        return Ok(());
    }

    let (hkey, _) = HKEY::CURRENT_USER
        .RegCreateKeyEx(
            &key,
            None,
            co::REG_OPTION::default(),
            co::KEY::READ | co::KEY::WRITE,
            None,
        )
        .map_err(|err| format!("无法创建资源管理器挂载点项：{err}"))?;

    hkey.RegSetValueEx(Some(LABEL_VALUE), RegistryValue::Sz(label))
        .map_err(|err| format!("无法写入 {LABEL_VALUE}：{err}"))
}

/// Removes the label of the share at `unc` when it is still the value this
/// wizard wrote.
///
/// A name the user changed by hand is deliberately preserved, and a share
/// without a label is not an error: the mapping is what is being torn down, the
/// label is only its presentation.
fn remove_drive_label(unc: &str) {
    let Some(username) = sshfs_username(unc) else {
        return;
    };
    let key = mount_points_key(unc);
    let current =
        HKEY::CURRENT_USER.RegGetValue(Some(&key), Some(LABEL_VALUE), co::RRF::RT_ANY);
    let ours = matches!(
        current,
        Ok(RegistryValue::Sz(text)) if text == drive_label(username)
    );
    if !ours {
        return;
    }

    if let Ok(hkey) = HKEY::CURRENT_USER.RegOpenKeyEx(
        Some(&key),
        co::REG_OPTION::default(),
        co::KEY::READ | co::KEY::WRITE,
    ) {
        let _ = hkey.RegDeleteValue(Some(LABEL_VALUE));
    }
}

/// UNC path that `letter` is currently connected to, if any.
///
/// `WNetGetConnectionW` is tried first; when it cannot answer (a 32-bit WOW64
/// process cannot reach the 64-bit WinFsp.Np at all) the WinFsp volume name is
/// resolved directly through `QueryDosDeviceW`.
fn active_connection(letter: char) -> Option<String> {
    mpr_connection(letter).or_else(|| dos_device_connection(letter))
}

/// UNC path reported by `WNetGetConnectionW` ("mpr.dll"), if any.
fn mpr_connection(letter: char) -> Option<String> {
    let local_w = win32::wide(&format!("{letter}:"));

    let mut buffer = vec![0u16; REMOTE_NAME_LEN];
    let mut length = REMOTE_NAME_LEN as u32;
    let status = unsafe { WNetGetConnectionW(local_w.as_ptr(), buffer.as_mut_ptr(), &mut length) };
    if status != 0 {
        return None;
    }

    Some(win32::from_wide(&buffer))
}

/// UNC path parsed out of the WinFsp volume name behind `letter`.
///
/// WinFsp.Np's `NPGetConnection` (`src/dll/np.c`) resolves the drive with
/// `QueryDosDeviceW`, which yields
/// `\Device\Volume{GUID}\sshfs\<user>@nas.chn.moe` for a WinFsp mount. The DOS
/// device map is a kernel object and is not affected by WOW64, so this works
/// from a 32-bit process where `WNetGetConnectionW` cannot. It is also the
/// fastest probe: no provider enumeration and no subprocess.
fn dos_device_connection(letter: char) -> Option<String> {
    let local_w = win32::wide(&format!("{letter}:"));

    let mut buffer = vec![0u16; REMOTE_NAME_LEN];
    let length =
        unsafe { QueryDosDeviceW(local_w.as_ptr(), buffer.as_mut_ptr(), buffer.len() as u32) };
    if length == 0 {
        return None;
    }

    // `\Device\Volume{GUID}\Server\Share`: the third backslash starts the
    // volume prefix that WinFsp keeps the UNC path in, exactly as
    // `NPGetConnection` splits it.
    let device = win32::from_wide(&buffer);
    let mut backslashes = 0;
    for (index, ch) in device.char_indices() {
        if ch == '\\' {
            backslashes += 1;
            if backslashes == 3 {
                return Some(format!("\\{}", &device[index..]));
            }
        }
    }
    None
}

/// UNC path of the persistent mapping saved in `HKCU\Network\<Letter>`.
fn saved_connection(letter: char) -> Option<String> {
    let sub_key = format!(r"Network\{letter}");
    match HKEY::CURRENT_USER.RegGetValue(Some(&sub_key), Some("RemotePath"), co::RRF::RT_ANY) {
        Ok(RegistryValue::Sz(text)) | Ok(RegistryValue::ExpandSz(text)) => Some(text),
        _ => None,
    }
}

/// Disconnects the mapping on `drive` (e.g. `"Z:"` or `"Z:\"`) and forgets the
/// saved password, so the drive does not come back at the next logon.
pub fn unmap_drive(drive: &str) -> Result<(), String> {
    let drive = drive.trim_end_matches('\\');

    // Capture the share before cancelling: `CONNECT_UPDATE_PROFILE` also
    // deletes `HKCU\Network\<letter>`, and the active connection disappears
    // with the drive, so neither path is readable afterwards.
    let letter = drive.chars().next().map(|letter| letter.to_ascii_uppercase());
    let share = letter.and_then(|letter| {
        active_connection(letter).or_else(|| saved_connection(letter))
    });

    if needs_native_net() {
        // 32-bit MPR cannot reach the 64-bit WinFsp.Np; the native 64-bit
        // `net.exe` can (see [`needs_native_net`]).
        let output = run_net(
            &["use", drive, "/delete", "/y"],
            &format!("use {drive} /delete /y（断开连接）"),
        )?;
        if output.code != 0 {
            crate::log::line(format!(
                "net.exe 断开 {drive} 返回退出码 {}（连接可能本就不存在）",
                output.code
            ));
        }

        // A non-zero exit code is harmless when there was nothing to delete,
        // so only a connection that is still there counts as a failure.
        let still_mapped = letter.is_some_and(|letter| {
            active_connection(letter).is_some() || saved_connection(letter).is_some()
        });
        if still_mapped {
            return Err(format!("断开 {drive} 失败：net.exe 退出码 {}", output.code));
        }
    } else {
        let drive_w = win32::wide(drive);

        // `CONNECT_UPDATE_PROFILE` removes the persistent connection from the
        // user's profile as well; `force` tears the connection down even while
        // a file on the share is still open.
        let status = unsafe { WNetCancelConnection2W(drive_w.as_ptr(), CONNECT_UPDATE_PROFILE, 1) };
        if status != 0 && status != ERROR_NOT_CONNECTED {
            return Err(format!("断开 {drive} 失败：{}", error_text(status)));
        }
    }

    if let Some(share) = share {
        remove_drive_label(&share);
    }
    forget_sshfs_credentials();
    Ok(())
}

/// Deletes the `CRED_TYPE_GENERIC` credentials WinFsp.Np looks up for this
/// server, so a disconnected drive leaves no stale password behind.
///
/// The target names include the user name (`\\sshfs\<user>@nas.chn.moe`), which
/// [`unmap_drive`] is not told, so the credentials are enumerated instead.
fn forget_sshfs_credentials() {
    let mut count = 0u32;
    let mut credentials: *mut *const CredentialW = std::ptr::null_mut();
    if unsafe { CredEnumerateW(std::ptr::null(), 0, &mut count, &mut credentials) } == 0 {
        return;
    }

    for index in 0..count as usize {
        let credential = unsafe { *credentials.add(index) };
        if credential.is_null() {
            continue;
        }

        let target = win32::from_wide_ptr(unsafe { (*credential).target_name });
        if !is_sshfs_target(&target) {
            continue;
        }

        let target_w = win32::wide(&target);
        unsafe { CredDeleteW(target_w.as_ptr(), CRED_TYPE_GENERIC, 0) };
    }

    unsafe { CredFree(credentials.cast()) };
}

fn error_text(code: u32) -> String {
    format!(
        "错误 {code}：{}",
        std::io::Error::from_raw_os_error(code as i32)
    )
}
