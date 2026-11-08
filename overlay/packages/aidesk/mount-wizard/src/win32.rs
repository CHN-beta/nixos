//! Thin wrappers over the few raw Win32 entry points that `winsafe` does not
//! wrap the way the wizard needs them: `ShellExecuteW` (open a URL with the
//! default handler), `ShellExecuteExW` + `WaitForSingleObject` (elevate and
//! wait for the elevated program to finish), `IsUserAnAdmin`, plus UTF-16 and
//! hidden-console helpers used by every subprocess the wizard spawns.

use std::ffi::{c_void, OsStr};
use std::os::windows::ffi::OsStrExt;
use std::os::windows::process::CommandExt;
use std::process::Command;

use winsafe::{self as w, co, prelude::*};

/// `CREATE_NO_WINDOW`: console programs spawned by the GUI must not flash a
/// console window.
pub const CREATE_NO_WINDOW: u32 = 0x0800_0000;

const SW_SHOWNORMAL: i32 = 1;

/// `SEE_MASK_NOCLOSEPROCESS`: keep `hProcess` open after the call, so the
/// caller can wait for the launched program.
const SEE_MASK_NOCLOSEPROCESS: u32 = 0x0000_0040;

/// `INFINITE`.
const INFINITE: u32 = 0xFFFF_FFFF;

/// `ERROR_CANCELLED`: the user declined the UAC prompt.
const ERROR_CANCELLED: i32 = 1223;

/// `SHELLEXECUTEINFOW`, as laid out on 64-bit Windows.
#[repr(C)]
struct ShellExecuteInfoW {
    cb_size: u32,
    f_mask: u32,
    hwnd: *mut c_void,
    verb: *const u16,
    file: *const u16,
    parameters: *const u16,
    directory: *const u16,
    show: i32,
    h_inst_app: *mut c_void,
    id_list: *mut c_void,
    class: *const u16,
    hkey_class: *mut c_void,
    hot_key: u32,
    h_icon: *mut c_void,
    h_process: *mut c_void,
}

#[link(name = "shell32")]
extern "system" {
    fn ShellExecuteW(
        hwnd: *mut c_void,
        operation: *const u16,
        file: *const u16,
        parameters: *const u16,
        directory: *const u16,
        show_cmd: i32,
    ) -> isize;

    fn ShellExecuteExW(info: *mut ShellExecuteInfoW) -> i32;

    fn IsUserAnAdmin() -> i32;
}

#[link(name = "kernel32")]
extern "system" {
    fn WaitForSingleObject(handle: *mut c_void, milliseconds: u32) -> u32;

    fn GetExitCodeProcess(process: *mut c_void, exit_code: *mut u32) -> i32;

    fn CloseHandle(handle: *mut c_void) -> i32;
}

/// NUL-terminated UTF-16 copy of `text`.
pub fn wide(text: &str) -> Vec<u16> {
    OsStr::new(text)
        .encode_wide()
        .chain(std::iter::once(0))
        .collect()
}

/// Copies the NUL-terminated UTF-16 `slice` into an owned `String`.
pub fn from_wide(slice: &[u16]) -> String {
    let end = slice
        .iter()
        .position(|unit| *unit == 0)
        .unwrap_or(slice.len());
    String::from_utf16_lossy(&slice[..end])
}

/// Copies the NUL-terminated UTF-16 string at `ptr` into an owned `String`.
pub fn from_wide_ptr(ptr: *const u16) -> String {
    if ptr.is_null() {
        return String::new();
    }

    let mut len = 0;
    while unsafe { *ptr.add(len) } != 0 {
        len += 1;
    }

    String::from_utf16_lossy(unsafe { std::slice::from_raw_parts(ptr, len) })
}

/// Spawns a subprocess with no console window.
pub fn command(program: impl AsRef<OsStr>) -> Command {
    let mut cmd = Command::new(program);
    cmd.creation_flags(CREATE_NO_WINDOW);
    cmd
}

/// `ShellExecuteW`. `verb` is `"runas"` to elevate or `"open"` to use the
/// default handler. Returns as soon as the program was *started*; use
/// [`shell_execute_wait`] when the caller depends on its result.
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

/// `ShellExecuteW` followed by a wait: launches `file` with `verb` (for
/// example `"runas"`, which raises the UAC prompt) and blocks until the
/// launched program exits, returning its exit code.
///
/// `ShellExecuteW` alone returns before the user has even clicked "Yes" on the
/// UAC prompt, let alone before the elevated helper or the MSI installer has
/// done its work — which made the wizard report success that had not happened
/// yet.
pub fn shell_execute_wait(verb: &str, file: &str, parameters: &str) -> Result<u32, String> {
    let verb_w = wide(verb);
    let file_w = wide(file);
    let parameters_w = wide(parameters);

    let mut info = ShellExecuteInfoW {
        cb_size: std::mem::size_of::<ShellExecuteInfoW>() as u32,
        f_mask: SEE_MASK_NOCLOSEPROCESS,
        hwnd: std::ptr::null_mut(),
        verb: verb_w.as_ptr(),
        file: file_w.as_ptr(),
        parameters: parameters_w.as_ptr(),
        directory: std::ptr::null(),
        show: SW_SHOWNORMAL,
        h_inst_app: std::ptr::null_mut(),
        id_list: std::ptr::null_mut(),
        class: std::ptr::null(),
        hkey_class: std::ptr::null_mut(),
        hot_key: 0,
        h_icon: std::ptr::null_mut(),
        h_process: std::ptr::null_mut(),
    };

    if unsafe { ShellExecuteExW(&mut info) } == 0 {
        return Err(launch_error(file));
    }

    // Handlers that resolve to a shell shortcut may not report a process at
    // all; there is nothing to wait for in that case.
    if info.h_process.is_null() {
        return Ok(0);
    }

    let process = info.h_process;
    unsafe { WaitForSingleObject(process, INFINITE) };

    let mut exit_code = 0u32;
    let has_exit_code = unsafe { GetExitCodeProcess(process, &mut exit_code) } != 0;
    unsafe { CloseHandle(process) };

    if has_exit_code {
        Ok(exit_code)
    } else {
        Err(format!(
            "无法读取 {file} 的退出码：{}",
            std::io::Error::last_os_error()
        ))
    }
}

fn launch_error(file: &str) -> String {
    let err = std::io::Error::last_os_error();
    if err.raw_os_error() == Some(ERROR_CANCELLED) {
        format!("用户取消了权限提升请求（{file}）。")
    } else {
        format!("无法启动 {file}：{err}")
    }
}

/// `true` when the current process token is elevated.
pub fn is_admin() -> bool {
    unsafe { IsUserAnAdmin() != 0 }
}

pub fn info_box(text: &str) {
    let _ = w::HWND::NULL.MessageBox(
        text,
        crate::ui::WIN_TITLE,
        co::MB::OK | co::MB::ICONINFORMATION,
    );
}

pub fn error_box(text: &str) {
    let _ = w::HWND::NULL.MessageBox(
        text,
        crate::ui::WIN_TITLE,
        co::MB::OK | co::MB::ICONERROR,
    );
}
