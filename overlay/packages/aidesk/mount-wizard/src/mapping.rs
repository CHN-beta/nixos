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

use std::time::Duration;

use winsafe::{co, HKEY, RegistryValue};

use crate::{win32, SERVER};

const RESOURCETYPE_DISK: u32 = 0x0000_0001;
const CONNECT_UPDATE_PROFILE: u32 = 0x0000_0001;

/// `CRED_TYPE_GENERIC`: the type WinFsp.Np reads.
const CRED_TYPE_GENERIC: u32 = 0x0000_0001;

/// `CRED_PERSIST_ENTERPRISE`: roams with the profile of domain users and stays
/// local for everybody else.
const CRED_PERSIST_ENTERPRISE: u32 = 0x0000_0003;

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

pub struct MapOutcome {
    pub ok: bool,
    pub log: Vec<String>,
}

/// Maps `\\sshfs\<username>@nas.chn.moe` onto `drive` (e.g. `"Z:"`).
pub fn map_drive(drive: &str, username: &str, password: &str) -> MapOutcome {
    let mut log = Vec::new();

    let unc = format!(r"\\sshfs\{username}@{SERVER}");
    let drive_root = format!("{drive}\\");

    log.push(format!("目标盘符：{drive}"));
    log.push(format!("远程路径：{unc}（远程主目录）"));

    // Seed the Explorer name before connecting. The shell may paint the new
    // drive as soon as `WNetAddConnection2W` reports it, so the value has to be
    // in place before that: reading it is what turns the UNC path into
    // `AIDesk(<user>)`. A failure here is not fatal — the drive is usable
    // without a custom name — and is reported by the write after the mount.
    let _ = set_drive_label(username);

    // A stale mapping on the same letter makes WNetAddConnection2W fail with
    // ERROR_ALREADY_ASSIGNED, so drop it first. "Not connected" is expected.
    let drive_w = win32::wide(drive);
    if unsafe { WNetCancelConnection2W(drive_w.as_ptr(), 0, 1) } == 0 {
        log.push(format!("已断开 {drive} 上的旧连接。"));
    }

    let local_w = win32::wide(drive);
    let remote_w = win32::wide(&unc);
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

    // Store the password as a generic credential keyed by the UNC path; this
    // is exactly what WinFsp.Np reads when it needs the password. The
    // credential must exist before the connection is attempted, because the
    // connection below passes no password at all.
    let credential_saved = match remember_credential(&unc, username, password) {
        Ok(()) => {
            log.push("密码已保存到 Windows 凭据管理器。".to_owned());
            true
        }
        Err(err) => {
            log.push(format!("保存密码到 Windows 凭据管理器失败：{err}"));
            false
        }
    };

    log.push("正在建立 SSH 连接（首次连接可能需要数秒）……".to_owned());

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
        log.push(format!("映射失败：{}", error_text(status)));
        log.push("请确认 WinFsp 与 SSHFS-Win 已安装，且用户名、密码正确。".to_owned());
        return MapOutcome { ok: false, log };
    }

    if matches!(
        winsafe::GetDriveType(Some(&drive_root)),
        winsafe::co::DRIVE::REMOTE
    ) {
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
        Ok(()) => log.push(format!("「此电脑」中显示为 {}。", drive_label(username))),
        Err(err) => log.push(format!("设置网盘显示名称失败：{err}")),
    }

    MapOutcome { ok: true, log }
}

/// Connects, retrying while the drive letter is still being released by the
/// cancelled mapping (WinFsp stops the previous service asynchronously).
fn connect_retrying(
    resource: &NetResourceW,
    password: *const u16,
    username: *const u16,
) -> u32 {
    let connect =
        || unsafe { WNetAddConnection2W(resource, password, username, CONNECT_UPDATE_PROFILE) };
    let mut status = connect();
    for _ in 0..10 {
        if status != ERROR_ALREADY_ASSIGNED {
            break;
        }
        std::thread::sleep(Duration::from_millis(500));
        status = connect();
    }
    status
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

    if unsafe { CredWriteW(&credential, 0) } != 0 {
        Ok(())
    } else {
        Err(format!(
            "CredWriteW 失败：{}",
            std::io::Error::last_os_error()
        ))
    }
}

/// Drive letter of the SSHFS mapping to the AIDesk server, e.g. `"Z:"`.
///
/// Every letter is probed: `WNetGetConnectionW` reports the UNC path of an
/// active network connection, while `HKCU\Network\<Letter>` keeps the paths of
/// persistent mappings even when the connection is momentarily down (right
/// after logon, or after a dropped link). Both are matched against
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
fn active_connection(letter: char) -> Option<String> {
    let local_w = win32::wide(&format!("{letter}:"));

    let mut buffer = vec![0u16; REMOTE_NAME_LEN];
    let mut length = REMOTE_NAME_LEN as u32;
    let status = unsafe { WNetGetConnectionW(local_w.as_ptr(), buffer.as_mut_ptr(), &mut length) };
    if status != 0 {
        return None;
    }

    Some(win32::from_wide(&buffer))
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
    let share = drive.chars().next().and_then(|letter| {
        let letter = letter.to_ascii_uppercase();
        active_connection(letter).or_else(|| saved_connection(letter))
    });

    let drive_w = win32::wide(drive);

    // `CONNECT_UPDATE_PROFILE` removes the persistent connection from the
    // user's profile as well; `force` tears the connection down even while a
    // file on the share is still open.
    let status = unsafe { WNetCancelConnection2W(drive_w.as_ptr(), CONNECT_UPDATE_PROFILE, 1) };
    if status != 0 && status != ERROR_NOT_CONNECTED {
        return Err(format!("断开 {drive} 失败：{}", error_text(status)));
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
