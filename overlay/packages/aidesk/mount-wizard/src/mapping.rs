//! Drive mapping and credential persistence.
//!
//! Two Win32 facts shape this module:
//!
//! * `WNetAddConnection2W` (mpr.dll) is the same code path `net use` uses.
//!   With `CONNECT_UPDATE_PROFILE` the mapping is remembered and re-created at
//!   the next logon.
//! * The WinFsp network provider (WinFsp.Np) looks the password up in the
//!   Windows Credential Manager — a generic credential whose target is the UNC
//!   path — whenever no password is passed inline, and hands it to the file
//!   system service. That is what makes the mapping reconnect unattended.
//!
//! Therefore the password is stored with `cmdkey` first and the connection is
//! then established without inline credentials; passing the password inline
//! (plus `CONNECT_CMD_SAVECRED`) remains as a fallback for machines where the
//! credential store is not reachable.

use std::time::Duration;

use crate::{win32, SERVER};

const RESOURCETYPE_DISK: u32 = 0x0000_0001;
const CONNECT_UPDATE_PROFILE: u32 = 0x0000_0001;
const CONNECT_CMD_SAVECRED: u32 = 0x0000_0010;

/// `ERROR_ALREADY_ASSIGNED`: the drive letter is still held by the mapping we
/// just cancelled.
const ERROR_ALREADY_ASSIGNED: u32 = 85;

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

#[link(name = "mpr")]
extern "system" {
    fn WNetAddConnection2W(
        resource: *const NetResourceW,
        password: *const u16,
        username: *const u16,
        flags: u32,
    ) -> u32;

    fn WNetCancelConnection2W(name: *const u16, flags: u32, force: i32) -> u32;
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
    // is exactly what WinFsp.Np reads when it needs the password.
    match remember_credential(&unc, username, password) {
        Ok(()) => log.push("密码已保存到 Windows 凭据管理器。".to_owned()),
        Err(err) => log.push(format!("保存密码到 Windows 凭据管理器失败：{err}")),
    }

    log.push("正在建立 SSH 连接（首次连接可能需要数秒）……".to_owned());

    let mut status = connect_retrying(
        &resource,
        std::ptr::null(),
        std::ptr::null(),
        CONNECT_UPDATE_PROFILE,
    );

    if status != 0 {
        log.push(format!(
            "凭据管理器方式未成功（{}），改用密码直连重试。",
            error_text(status)
        ));
        status = connect_retrying(
            &resource,
            password_w.as_ptr(),
            username_w.as_ptr(),
            CONNECT_UPDATE_PROFILE | CONNECT_CMD_SAVECRED,
        );
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
    log.push("登录 Windows 时会使用保存的密码自动重连。".to_owned());

    MapOutcome { ok: true, log }
}

/// Connects, retrying while the drive letter is still being released by the
/// cancelled mapping (WinFsp stops the previous service asynchronously).
fn connect_retrying(
    resource: &NetResourceW,
    password: *const u16,
    username: *const u16,
    flags: u32,
) -> u32 {
    let mut status = unsafe { WNetAddConnection2W(resource, password, username, flags) };
    for _ in 0..10 {
        if status != ERROR_ALREADY_ASSIGNED {
            break;
        }
        std::thread::sleep(Duration::from_millis(500));
        status = unsafe { WNetAddConnection2W(resource, password, username, flags) };
    }
    status
}

fn remember_credential(target: &str, username: &str, password: &str) -> Result<(), String> {
    let output = win32::command("cmdkey.exe")
        .arg(format!("/add:{target}"))
        .arg(format!("/user:{username}"))
        .arg(format!("/pass:{password}"))
        .output()
        .map_err(|err| err.to_string())?;

    if output.status.success() {
        Ok(())
    } else {
        let stderr = String::from_utf8_lossy(&output.stderr).trim().to_owned();
        Err(if stderr.is_empty() {
            format!("cmdkey 退出码 {}", output.status.code().unwrap_or(-1))
        } else {
            stderr
        })
    }
}

fn error_text(code: u32) -> String {
    format!(
        "错误 {code}：{}",
        std::io::Error::from_raw_os_error(code as i32)
    )
}
