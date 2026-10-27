//! Native PTY terminal sessions.
//!
//! Each session owns a `libc::openpty` pair, a child process in its own
//! session/process group, an async reader on the master fd, and a 256 KiB ring
//! buffer of recent output that new SSE subscribers receive first.

use serde::Serialize;
use serde_json::{json, Value};
use std::collections::{HashMap, VecDeque};
use std::fs::File;
use std::os::fd::{AsRawFd, FromRawFd, RawFd};
use std::os::unix::process::CommandExt;
use std::path::Path;
use std::process::{Child, Command, Stdio};
use std::sync::atomic::{AtomicBool, AtomicI64, Ordering};
use std::sync::{Arc, Mutex};
use std::time::{Duration, Instant, SystemTime, UNIX_EPOCH};
use tokio::io::unix::AsyncFd;
use tokio::sync::broadcast;

pub const MAX_BUFFER_BYTES: usize = 256 * 1024;

/// Mark a descriptor close-on-exec so PTY fds never leak into spawned children
/// (including `omp` processes started by the agent layer).
fn set_cloexec(fd: RawFd) -> std::io::Result<()> {
    let flags = unsafe { libc::fcntl(fd, libc::F_GETFD) };
    if flags < 0 {
        return Err(std::io::Error::last_os_error());
    }
    if unsafe { libc::fcntl(fd, libc::F_SETFD, flags | libc::FD_CLOEXEC) } < 0 {
        return Err(std::io::Error::last_os_error());
    }
    Ok(())
}

/// `dup(2)` that reports failure instead of passing `-1` to `from_raw_fd`.
fn dup_fd(fd: RawFd) -> std::io::Result<RawFd> {
    let duped = unsafe { libc::dup(fd) };
    if duped < 0 {
        return Err(std::io::Error::last_os_error());
    }
    if let Err(error) = set_cloexec(duped) {
        unsafe {
            libc::close(duped);
        }
        return Err(error);
    }
    Ok(duped)
}

fn dup_stdio(slave: RawFd) -> std::io::Result<(Stdio, Stdio, Stdio)> {
    let stdin = dup_fd(slave)?;
    let stdout = match dup_fd(slave) {
        Ok(fd) => fd,
        Err(error) => {
            unsafe {
                libc::close(stdin);
            }
            return Err(error);
        }
    };
    let stderr = match dup_fd(slave) {
        Ok(fd) => fd,
        Err(error) => {
            unsafe {
                libc::close(stdin);
                libc::close(stdout);
            }
            return Err(error);
        }
    };
    Ok(unsafe {
        (
            Stdio::from_raw_fd(stdin),
            Stdio::from_raw_fd(stdout),
            Stdio::from_raw_fd(stderr),
        )
    })
}

fn epoch_ms() -> i64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_millis() as i64)
        .unwrap_or(0)
}

/// Pick an executable shell: explicit request, $SHELL, conventional absolute
/// paths, then PATH (`sh`, `bash`). Nix build sandboxes have no `/bin/sh`.
fn resolve_shell(requested: Option<&str>) -> String {
    let explicit: Vec<String> = requested
        .filter(|shell| !shell.is_empty())
        .map(|shell| vec![shell.to_string()])
        .unwrap_or_default();
    let candidates = explicit
        .into_iter()
        .chain(std::env::var("SHELL").ok())
        .chain(["/bin/bash".to_string(), "/bin/sh".to_string()]);
    for candidate in candidates {
        if Path::new(&candidate).is_file() {
            return candidate;
        }
    }
    if let Ok(path_var) = std::env::var("PATH") {
        for name in ["bash", "sh"] {
            for dir in path_var.split(':') {
                if dir.is_empty() {
                    continue;
                }
                let candidate = Path::new(dir).join(name);
                if candidate.is_file() {
                    return candidate.to_string_lossy().into_owned();
                }
            }
        }
    }
    "sh".to_string()
}

#[derive(Debug, Clone, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct TerminalInfo {
    pub id: String,
    pub pid: i32,
    pub cwd: String,
    pub cols: u16,
    pub rows: u16,
    pub created_at: i64,
    pub last_active_at: i64,
}

#[derive(Debug, Clone)]
pub enum TerminalEvent {
    Output(String),
    Exit(i32),
}

pub struct TerminalSession {
    pub id: String,
    pub cwd: String,
    pub pid: i32,
    created_at: i64,
    cols: AtomicI64,
    rows: AtomicI64,
    last_active_at: AtomicI64,
    buffer: Mutex<VecDeque<u8>>,
    buffer_bytes: AtomicI64,
    exited: AtomicBool,
    exit_code: AtomicI64,
    master_fd: RawFd,
    child: Mutex<Option<Child>>,
    events: broadcast::Sender<TerminalEvent>,
}

impl Drop for TerminalSession {
    fn drop(&mut self) {
        self.kill();
        unsafe {
            libc::close(self.master_fd);
        }
    }
}

fn set_winsize(fd: RawFd, cols: u16, rows: u16) {
    let size = libc::winsize {
        ws_row: rows,
        ws_col: cols,
        ws_xpixel: 0,
        ws_ypixel: 0,
    };
    unsafe {
        libc::ioctl(fd, libc::TIOCSWINSZ, &size);
    }
}

impl TerminalSession {
    pub fn spawn(
        id: String,
        cwd: &str,
        cols: u16,
        rows: u16,
        shell: Option<&str>,
    ) -> std::io::Result<Arc<Self>> {
        let shell_path = resolve_shell(shell);

        let mut master: RawFd = -1;
        let mut slave: RawFd = -1;
        let size = libc::winsize {
            ws_row: rows,
            ws_col: cols,
            ws_xpixel: 0,
            ws_ypixel: 0,
        };
        let result = unsafe {
            libc::openpty(
                &mut master,
                &mut slave,
                std::ptr::null_mut(),
                std::ptr::null(),
                &size,
            )
        };
        if result != 0 {
            return Err(std::io::Error::last_os_error());
        }
        // The master must never leak into a child; the reader works on a
        // close-on-exec dup so the session keeps its own fd for writes.
        if let Err(error) = set_cloexec(master) {
            unsafe {
                libc::close(master);
                libc::close(slave);
            }
            return Err(error);
        }
        let read_fd = match dup_fd(master) {
            Ok(fd) => fd,
            Err(error) => {
                unsafe {
                    libc::close(master);
                    libc::close(slave);
                }
                return Err(error);
            }
        };

        let working_dir = if Path::new(cwd).is_dir() {
            cwd.to_string()
        } else {
            std::env::var("HOME").unwrap_or_else(|_| "/".to_string())
        };

        let (stdin, stdout, stderr) = match dup_stdio(slave) {
            Ok(stdio) => stdio,
            Err(error) => {
                unsafe {
                    libc::close(master);
                    libc::close(slave);
                    libc::close(read_fd);
                }
                return Err(error);
            }
        };
        let mut command = Command::new(&shell_path);
        command
            .arg("-i")
            .current_dir(&working_dir)
            .env("TERM", "xterm-256color")
            .env("COLORTERM", "truecolor")
            .stdin(stdin)
            .stdout(stdout)
            .stderr(stderr);
        // New session/process group so killpg reaches the whole tree. The
        // slave (stdin) becomes the controlling terminal, which interactive
        // shells need for /dev/tty and job control.
        unsafe {
            command.pre_exec(|| {
                if libc::setsid() < 0 {
                    return Err(std::io::Error::last_os_error());
                }
                // Failure here leaves a working (if tty-less) shell, so do not
                // abort the spawn over it.
                libc::ioctl(0, libc::TIOCSCTTY as _, 0);
                Ok(())
            });
        }
        let child = match command.spawn() {
            Ok(child) => child,
            Err(error) => {
                unsafe {
                    libc::close(master);
                    libc::close(slave);
                    libc::close(read_fd);
                }
                return Err(error);
            }
        };
        unsafe {
            libc::close(slave);
        }
        // Non-blocking master fd so the async reader never blocks a runtime
        // worker; writes retry on EAGAIN.
        unsafe {
            let flags = libc::fcntl(master, libc::F_GETFL);
            if flags >= 0 {
                libc::fcntl(master, libc::F_SETFL, flags | libc::O_NONBLOCK);
            }
        }
        let pid = child.id() as i32;
        let (events, _) = broadcast::channel(512);
        let now = epoch_ms();
        let session = Arc::new(Self {
            id,
            cwd: working_dir,
            pid,
            created_at: now,
            cols: AtomicI64::new(cols as i64),
            rows: AtomicI64::new(rows as i64),
            last_active_at: AtomicI64::new(now),
            buffer: Mutex::new(VecDeque::new()),
            buffer_bytes: AtomicI64::new(0),
            exited: AtomicBool::new(false),
            exit_code: AtomicI64::new(0),
            master_fd: master,
            child: Mutex::new(Some(child)),
            events,
        });
        // Reader task owns an AsyncFd wrapper on a close-on-exec dup of the
        // master fd so the session's own fd stays valid for writes.
        let reader_session = session.clone();
        tokio::spawn(async move {
            let file = unsafe { File::from_raw_fd(read_fd) };
            #[allow(deprecated)]
            let async_fd = match AsyncFd::new(file) {
                Ok(fd) => fd,
                Err(_) => return,
            };
            let mut pending: Vec<u8> = Vec::new();
            loop {
                let mut guard = match async_fd.readable().await {
                    Ok(guard) => guard,
                    Err(_) => break,
                };
                let mut buffer = [0u8; 8192];
                match guard.try_io(|inner| {
                    let fd = inner.as_raw_fd();
                    let read = unsafe {
                        libc::read(fd, buffer.as_mut_ptr() as *mut libc::c_void, buffer.len())
                    };
                    if read < 0 {
                        Err(std::io::Error::last_os_error())
                    } else {
                        Ok(read as usize)
                    }
                }) {
                    Ok(Ok(0)) => break,
                    Ok(Ok(count)) => {
                        pending.extend_from_slice(&buffer[..count]);
                        // Emit complete UTF-8 sequences; a split multi-byte rune
                        // waits for the next read.
                        let valid_up_to = match std::str::from_utf8(&pending) {
                            Ok(_) => pending.len(),
                            Err(error) => error.valid_up_to(),
                        };
                        if valid_up_to > 0 {
                            let text =
                                String::from_utf8_lossy(&pending[..valid_up_to]).into_owned();
                            pending.drain(..valid_up_to);
                            reader_session.push_output(text);
                        }
                    }
                    // A signal interrupted the read; the fd is still readable.
                    Ok(Err(error)) if error.kind() == std::io::ErrorKind::Interrupted => continue,
                    Ok(Err(_)) => break,
                    Err(_would_block) => continue,
                }
            }
            reader_session.finish();
        });
        Ok(session)
    }

    fn push_output(&self, data: String) {
        self.last_active_at.store(epoch_ms(), Ordering::Relaxed);
        if let Ok(mut buffer) = self.buffer.lock() {
            buffer.extend(data.as_bytes());
            let mut total = self.buffer_bytes.load(Ordering::Relaxed) + data.len() as i64;
            while total > MAX_BUFFER_BYTES as i64 && buffer.len() > 1 {
                let excess = total - MAX_BUFFER_BYTES as i64;
                let drop_count = (excess as usize).min(buffer.len() - 1);
                buffer.drain(..drop_count);
                total -= drop_count as i64;
            }
            self.buffer_bytes.store(total, Ordering::Relaxed);
        }
        let _ = self.events.send(TerminalEvent::Output(data));
    }

    fn finish(&self) {
        if self.exited.swap(true, Ordering::SeqCst) {
            return;
        }
        let mut code = 0;
        let mut unreaped: Option<Child> = None;
        if let Ok(mut slot) = self.child.lock() {
            if let Some(child) = slot.as_mut() {
                match child.try_wait() {
                    Ok(Some(status)) => {
                        code = status.code().unwrap_or(0);
                        *slot = None;
                    }
                    // EIO on the master fd usually means the slave closed, but
                    // the child may still be flushing its exit: hand it to a
                    // blocking reaper so it can never linger as a zombie.
                    Ok(None) | Err(_) => unreaped = slot.take(),
                }
            }
        }
        if let Some(mut child) = unreaped {
            std::thread::spawn(move || {
                let _ = child.wait();
            });
        }
        self.exit_code.store(code as i64, Ordering::SeqCst);
        let _ = self.events.send(TerminalEvent::Exit(code));
    }

    pub fn history(&self) -> String {
        self.buffer
            .lock()
            .map(|buffer| {
                String::from_utf8_lossy(&buffer.iter().copied().collect::<Vec<u8>>()).into_owned()
            })
            .unwrap_or_default()
    }

    pub fn write_input(&self, data: &str) -> bool {
        if self.exited.load(Ordering::SeqCst) {
            return false;
        }
        self.last_active_at.store(epoch_ms(), Ordering::Relaxed);
        let bytes = data.as_bytes();
        let mut written = 0usize;
        let deadline = Instant::now() + Duration::from_secs(2);
        while written < bytes.len() {
            let count = unsafe {
                libc::write(
                    self.master_fd,
                    bytes[written..].as_ptr() as *const libc::c_void,
                    bytes.len() - written,
                )
            };
            if count > 0 {
                written += count as usize;
                continue;
            }
            let error = std::io::Error::last_os_error();
            match error.kind() {
                std::io::ErrorKind::Interrupted => continue,
                // The fd is non-blocking: wait for writability with poll()
                // instead of sleeping a Tokio worker thread.
                std::io::ErrorKind::WouldBlock => {
                    let remaining = deadline.saturating_duration_since(Instant::now());
                    if remaining.is_zero() {
                        return false;
                    }
                    let mut poll_fd = libc::pollfd {
                        fd: self.master_fd,
                        events: libc::POLLOUT,
                        revents: 0,
                    };
                    let timeout = remaining.as_millis().min(1000) as libc::c_int;
                    unsafe {
                        libc::poll(&mut poll_fd, 1, timeout.max(1));
                    }
                    continue;
                }
                _ => return false,
            }
        }
        true
    }

    pub fn resize(&self, cols: u16, rows: u16) -> bool {
        if self.exited.load(Ordering::SeqCst) {
            return false;
        }
        self.cols.store(cols as i64, Ordering::Relaxed);
        self.rows.store(rows as i64, Ordering::Relaxed);
        self.last_active_at.store(epoch_ms(), Ordering::Relaxed);
        set_winsize(self.master_fd, cols, rows);
        true
    }

    pub fn is_exited(&self) -> bool {
        self.exited.load(Ordering::SeqCst)
    }

    pub fn exit_code(&self) -> i32 {
        self.exit_code.load(Ordering::SeqCst) as i32
    }

    pub fn subscribe(&self) -> broadcast::Receiver<TerminalEvent> {
        self.events.subscribe()
    }

    pub fn kill(&self) {
        if !self.exited.load(Ordering::SeqCst) {
            // Hang up the foreground job, then the whole process group.
            set_winsize(
                self.master_fd,
                self.cols.load(Ordering::Relaxed) as u16,
                self.rows.load(Ordering::Relaxed) as u16,
            );
            unsafe {
                libc::kill(-self.pid, libc::SIGHUP);
                libc::kill(-self.pid, libc::SIGTERM);
            }
        }
        // Always take the child so it is guaranteed to be reaped, even if the
        // reader already marked the session exited (EIO arrives before wait).
        let child = self.child.lock().ok().and_then(|mut slot| slot.take());
        if let Some(mut child) = child {
            let _ = child.kill();
            // Reap off-thread: Drop may run on a Tokio worker.
            std::thread::spawn(move || {
                let _ = child.wait();
            });
        }
        self.finish();
    }

    pub fn info(&self) -> TerminalInfo {
        TerminalInfo {
            id: self.id.clone(),
            pid: self.pid,
            cwd: self.cwd.clone(),
            cols: self.cols.load(Ordering::Relaxed) as u16,
            rows: self.rows.load(Ordering::Relaxed) as u16,
            created_at: self.created_at,
            last_active_at: self.last_active_at.load(Ordering::Relaxed),
        }
    }
}

pub struct TerminalManager {
    sessions: Arc<Mutex<HashMap<String, Arc<TerminalSession>>>>,
}

impl TerminalManager {
    pub fn new() -> Self {
        Self {
            sessions: Arc::new(Mutex::new(HashMap::new())),
        }
    }

    pub fn create(
        &self,
        cwd: Option<&str>,
        cols: u16,
        rows: u16,
        shell: Option<&str>,
    ) -> std::io::Result<Arc<TerminalSession>> {
        let effective_cwd = cwd
            .filter(|cwd| Path::new(cwd).is_dir())
            .map(|cwd| cwd.to_string())
            .unwrap_or_else(|| {
                std::env::current_dir()
                    .map(|path| path.to_string_lossy().into_owned())
                    .unwrap_or_else(|_| "/".to_string())
            });
        let id = format!(
            "term_{}_{}",
            epoch_ms(),
            &uuid::Uuid::new_v4().simple().to_string()[..6]
        );
        let session = TerminalSession::spawn(id.clone(), &effective_cwd, cols, rows, shell)?;
        if let Ok(mut sessions) = self.sessions.lock() {
            sessions.insert(id.clone(), session.clone());
        }
        // Idle cleanup 10s after exit, mirroring the reference implementation.
        let sessions = self.sessions.clone();
        let session_for_task = session.clone();
        let id_for_task = id.clone();
        tokio::spawn(async move {
            let mut events = session_for_task.subscribe();
            loop {
                match events.recv().await {
                    Ok(TerminalEvent::Exit(_)) | Err(broadcast::error::RecvError::Closed) => break,
                    _ => continue,
                }
            }
            tokio::time::sleep(std::time::Duration::from_secs(10)).await;
            if let Ok(mut sessions) = sessions.lock() {
                if sessions
                    .get(&id_for_task)
                    .map(|session| session.is_exited())
                    .unwrap_or(false)
                {
                    sessions.remove(&id_for_task);
                }
            }
        });
        Ok(session)
    }

    pub fn get(&self, id: &str) -> Option<Arc<TerminalSession>> {
        self.sessions.lock().ok()?.get(id).cloned()
    }

    pub fn list(&self) -> Vec<Value> {
        self.sessions
            .lock()
            .map(|sessions| {
                sessions
                    .values()
                    .map(|session| json!(session.info()))
                    .collect()
            })
            .unwrap_or_default()
    }

    pub fn kill(&self, id: &str) -> bool {
        let session = self
            .sessions
            .lock()
            .ok()
            .and_then(|mut sessions| sessions.remove(id));
        match session {
            Some(session) => {
                session.kill();
                true
            }
            None => false,
        }
    }

    /// Tear down every PTY (server shutdown).
    pub fn kill_all(&self) {
        let sessions = self
            .sessions
            .lock()
            .map(|mut sessions| std::mem::take(&mut *sessions))
            .unwrap_or_default();
        for session in sessions.values() {
            session.kill();
        }
    }
}
