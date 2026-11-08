//! Thin wrappers over the few raw Win32 entry points that `winsafe` does not
//! wrap: `ShellExecuteW` (UAC elevation and "open with default handler"),
//! `IsUserAnAdmin`, plus UTF-16 and hidden-console helpers used by every
//! subprocess the wizard spawns.

use std::ffi::OsStr;
use std::os::windows::ffi::OsStrExt;
use std::os::windows::process::CommandExt;
use std::process::Command;

use winsafe::{self as w, co, prelude::*};

/// `CREATE_NO_WINDOW`: console programs spawned by the GUI must not flash a
/// console window.
pub const CREATE_NO_WINDOW: u32 = 0x0800_0000;

const SW_SHOWNORMAL: i32 = 1;

#[link(name = "shell32")]
extern "system" {
    fn ShellExecuteW(
        hwnd: *mut std::ffi::c_void,
        operation: *const u16,
        file: *const u16,
        parameters: *const u16,
        directory: *const u16,
        show_cmd: i32,
    ) -> isize;

    fn IsUserAnAdmin() -> i32;
}

/// NUL-terminated UTF-16 copy of `text`.
pub fn wide(text: &str) -> Vec<u16> {
    OsStr::new(text)
        .encode_wide()
        .chain(std::iter::once(0))
        .collect()
}

/// Spawns a subprocess with no console window.
pub fn command(program: impl AsRef<OsStr>) -> Command {
    let mut cmd = Command::new(program);
    cmd.creation_flags(CREATE_NO_WINDOW);
    cmd
}

/// `ShellExecuteW`. `verb` is `"runas"` to elevate or `"open"` to use the
/// default handler.
pub fn shell_execute(verb: &str, file: &str, parameters: &str) -> Result<(), String> {
    let verb_w = wide(verb);
    let file_w = wide(file);
    let parameters_w = wide(parameters);

    let ret = unsafe {
        ShellExecuteW(
            std::ptr::null_mut(),
            verb_w.as_ptr(),
            file_w.as_ptr(),
            parameters_w.as_ptr(),
            std::ptr::null(),
            SW_SHOWNORMAL,
        )
    };

    // ShellExecuteW returns a pseudo HINSTANCE; values <= 32 are error codes.
    if ret <= 32 {
        Err(format!("ShellExecuteW 失败（错误码 {ret}）"))
    } else {
        Ok(())
    }
}

/// `true` when the current process token is elevated.
pub fn is_admin() -> bool {
    unsafe { IsUserAnAdmin() != 0 }
}

pub fn info_box(text: &str) {
    let _ = w::HWND::NULL.MessageBox(
        text,
        "AIDesk 网络驱动器向导",
        co::MB::OK | co::MB::ICONINFORMATION,
    );
}

pub fn error_box(text: &str) {
    let _ = w::HWND::NULL.MessageBox(
        text,
        "AIDesk 网络驱动器向导",
        co::MB::OK | co::MB::ICONERROR,
    );
}
