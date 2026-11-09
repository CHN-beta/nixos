//! Diagnostic log file.
//!
//! The wizard is a GUI program, so there is no console to read a failure from
//! and the user only sees a short message box. Every step that can fail
//! (dependency probing, registry reads/writes, the drive mapping itself)
//! therefore appends a line to a log file as well, which makes a remote
//! "it does not work" report diagnosable.
//!
//! The file lives next to the executable so a portable copy carries it along;
//! when that directory is read-only (for example when the wizard runs from a
//! protected location) it falls back to `%TEMP%`.
//!
//! Every line opens the file in append mode, writes one line and flushes it
//! immediately: a crash or a hung `WNetAddConnection2W` must not lose the
//! lines that came before it.

use std::fs::OpenOptions;
use std::io::Write;
use std::path::{Path, PathBuf};
use std::sync::LazyLock;

use winsafe as w;

/// File name used both next to the executable and in the temporary directory.
const FILE_NAME: &str = "aidesk-mount-wizard.log";

/// Resolved log file path. Chosen once, on first use.
static LOG_PATH: LazyLock<PathBuf> = LazyLock::new(|| {
    let beside_exe = std::env::current_exe()
        .ok()
        .and_then(|exe| exe.parent().map(Path::to_path_buf))
        .map(|dir| dir.join(FILE_NAME));

    match beside_exe {
        Some(path) if openable(&path) => path,
        _ => std::env::temp_dir().join(FILE_NAME),
    }
});

/// Whether `path` can be opened for appending, creating it when needed.
fn openable(path: &Path) -> bool {
    OpenOptions::new()
        .create(true)
        .append(true)
        .open(path)
        .is_ok()
}

/// Path of the log file actually in use.
///
/// The directory of the running executable is preferred; if the file cannot
/// be opened there, `%TEMP%\aidesk-mount-wizard.log` is used instead.
pub fn path() -> &'static Path {
    LOG_PATH.as_path()
}

/// Local wall-clock timestamp with millisecond precision.
fn timestamp() -> String {
    let st = w::GetLocalTime();
    format!(
        "{:04}-{:02}-{:02} {:02}:{:02}:{:02}.{:03}",
        st.wYear, st.wMonth, st.wDay, st.wHour, st.wMinute, st.wSecond, st.wMilliseconds
    )
}

/// Appends one timestamped line to the log file and flushes it.
///
/// Logging is best-effort: a failure to write must never take the wizard down
/// or mask the error that is being logged.
pub fn line(message: impl AsRef<str>) {
    let text = format!("{} {}\r\n", timestamp(), message.as_ref());

    if let Ok(mut file) = OpenOptions::new()
        .create(true)
        .append(true)
        .open(path())
    {
        let _ = file.write_all(text.as_bytes());
        let _ = file.flush();
    }
}
