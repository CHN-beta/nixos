//! The four-page wizard UI.
//!
//! All controls are created up front on a fixed-size main window and shown or
//! hidden per page, which keeps the layout simple and avoids re-creating native
//! windows on every navigation step.

use std::cell::RefCell;
use std::rc::Rc;

use winsafe::{self as w, co, gui, prelude::*};

use crate::{deps, mapping, registry, win32, SERVER};

const PAGE1_BODY: &str = "\
本向导会把 AIDesk 的远程工作目录映射为本机的网络驱动器，\r\n\
并在每次登录时自动重连，用起来就像本地磁盘一样。\r\n\
\r\n\
向导将自动完成：\r\n\
  • 检查并安装 WinFsp 与 SSHFS-Win 两个底层依赖；\r\n\
  • 写入断线自动重连参数，降低网络波动造成的断连；\r\n\
  • 用 Windows 凭据管理器保存密码，映射后开机自动恢复。\r\n\
\r\n\
安装驱动需要管理员权限，届时会弹出 UAC 授权窗口。";

const PAGE2_HINT: &str = "\
WinFsp 与 SSHFS-Win 缺一不可。缺少任一组件时“下一步”不可用；\r\n\
安装完成后请点击“重新检查”。\r\n\
重连参数：ServerAliveInterval=15、ServerAliveCountMax=3、reconnect。";

const PAGE3_HINT: &str = "\
服务器：nas.chn.moe（SSH 默认端口 22）。\r\n\
映射地址：\\\\sshfs\\<用户名>@nas.chn.moe，对应账号的远程主目录。\r\n\
密码会保存到 Windows 凭据管理器中，用于开机自动重连。";

const PAGE4_HINT: &str = "\
点击“开始映射”将清理该盘符上的旧连接、写入重连参数，\r\n\
并用上面的账号建立映射（密码同时写入凭据管理器）。";

#[derive(Clone, Copy, PartialEq, Eq, Default)]
enum Page {
    #[default]
    Welcome,
    Deps,
    Account,
    Map,
}

#[derive(Default)]
struct State {
    page: Page,
    deps: deps::Status,
    mapped: bool,
    log: Vec<String>,
    notes: Vec<String>,
}

#[derive(Clone)]
struct Wizard {
    wnd: gui::WindowMain,
    state: Rc<RefCell<State>>,

    // Page 1
    p1_title: gui::Label,
    p1_body: gui::Label,

    // Page 2
    p2_title: gui::Label,
    p2_winfsp: gui::Label,
    p2_sshfs: gui::Label,
    p2_keepalive: gui::Label,
    p2_hint: gui::Label,
    p2_note: gui::Label,
    btn_install: gui::Button,
    btn_configure: gui::Button,

    // Page 3
    p3_title: gui::Label,
    lbl_user: gui::Label,
    edit_user: gui::Edit,
    lbl_pass: gui::Label,
    edit_pass: gui::Edit,
    lbl_drive: gui::Label,
    cmb_drive: gui::ComboBox,
    p3_hint: gui::Label,
    p3_error: gui::Label,

    // Page 4
    p4_title: gui::Label,
    p4_hint: gui::Label,
    edit_log: gui::Edit,

    // Navigation bar
    btn_back: gui::Button,
    btn_recheck: gui::Button,
    btn_next: gui::Button,
    btn_map: gui::Button,
    btn_open: gui::Button,
    btn_finish: gui::Button,
}

pub fn run() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    let wizard = Wizard::new();
    wizard.events();
    let _ = wizard.wnd.run_main(None)?;
    Ok(())
}

fn label(parent: &gui::WindowMain, text: &str, pos: (i32, i32), size: (i32, i32)) -> gui::Label {
    gui::Label::new(
        parent,
        gui::LabelOpts {
            text,
            position: gui::dpi(pos.0, pos.1),
            size: gui::dpi(size.0, size.1),
            ..Default::default()
        },
    )
}

fn button(parent: &gui::WindowMain, text: &str, pos: (i32, i32), width: i32) -> gui::Button {
    gui::Button::new(
        parent,
        gui::ButtonOpts {
            text,
            position: gui::dpi(pos.0, pos.1),
            width: gui::dpi_x(width),
            height: gui::dpi_y(28),
            ..Default::default()
        },
    )
}

fn edit(
    parent: &gui::WindowMain,
    pos: (i32, i32),
    width: i32,
    height: i32,
    password: bool,
) -> gui::Edit {
    let mut style = co::ES::AUTOHSCROLL | co::ES::NOHIDESEL;
    if password {
        style |= co::ES::PASSWORD;
    }
    gui::Edit::new(
        parent,
        gui::EditOpts {
            text: "",
            position: gui::dpi(pos.0, pos.1),
            width: gui::dpi_x(width),
            height: gui::dpi_y(height),
            control_style: style,
            ..Default::default()
        },
    )
}

fn available_drives() -> (Vec<String>, usize) {
    let mut drives: Vec<String> = ('A'..='Z')
        .rev()
        .map(|letter| format!("{letter}:"))
        .filter(|drive| {
            matches!(
                w::GetDriveType(Some(&format!("{drive}\\"))),
                co::DRIVE::NO_ROOT_DIR
            )
        })
        .collect();

    if drives.is_empty() {
        drives = vec!["Z:".to_owned(), "Y:".to_owned(), "X:".to_owned()];
    }

    let default_index = drives.iter().position(|drive| drive == "Z:").unwrap_or(0);
    (drives, default_index)
}

fn status_text(installed: bool) -> &'static str {
    if installed {
        "[已安装]"
    } else {
        "[未安装]"
    }
}

fn keepalive_text(configured: bool) -> &'static str {
    if configured {
        "[已配置]"
    } else {
        "[未配置]"
    }
}

impl Wizard {
    fn new() -> Self {
        let wnd = gui::WindowMain::new(gui::WindowMainOpts {
            title: "AIDesk 网络驱动器向导",
            size: gui::dpi(520, 380),
            ..Default::default()
        });

        let p1_title = label(&wnd, "欢迎使用 AIDesk 网络驱动器向导", (24, 22), (472, 26));
        let p1_body = label(&wnd, PAGE1_BODY, (24, 60), (472, 250));

        let p2_title = label(&wnd, "检查运行环境", (24, 22), (472, 26));
        let p2_winfsp = label(&wnd, "WinFsp：[未检查]", (24, 62), (472, 22));
        let p2_sshfs = label(&wnd, "SSHFS-Win：[未检查]", (24, 88), (472, 22));
        let p2_keepalive = label(&wnd, "断线重连参数：[未检查]", (24, 114), (472, 22));
        let p2_hint = label(&wnd, PAGE2_HINT, (24, 146), (472, 62));
        let btn_install = button(&wnd, "一键安装缺失组件", (24, 216), 160);
        let btn_configure = button(&wnd, "配置重连参数", (196, 216), 140);
        let p2_note = label(&wnd, "", (24, 252), (472, 62));

        let p3_title = label(&wnd, "填写账号与盘符", (24, 22), (472, 26));
        let lbl_user = label(&wnd, "AIDesk 用户名", (24, 62), (472, 20));
        let edit_user = edit(&wnd, (24, 84), 472, 26, false);
        let lbl_pass = label(&wnd, "密码", (24, 122), (472, 20));
        let edit_pass = edit(&wnd, (24, 144), 472, 26, true);
        let lbl_drive = label(&wnd, "要映射的盘符", (24, 184), (200, 20));

        let (drives, default_index) = available_drives();
        let drive_refs: Vec<&str> = drives.iter().map(String::as_str).collect();
        let cmb_drive = gui::ComboBox::new(
            &wnd,
            gui::ComboBoxOpts {
                position: gui::dpi(24, 206),
                width: gui::dpi_x(120),
                items: &drive_refs,
                selected_item: Some(default_index as u32),
                ..Default::default()
            },
        );

        let p3_hint = label(&wnd, PAGE3_HINT, (24, 242), (472, 56));
        let p3_error = label(&wnd, "", (24, 298), (472, 20));

        let p4_title = label(&wnd, "执行映射", (24, 22), (472, 26));
        let p4_hint = label(&wnd, PAGE4_HINT, (24, 56), (472, 40));
        let edit_log = gui::Edit::new(
            &wnd,
            gui::EditOpts {
                text: "",
                position: gui::dpi(24, 102),
                width: gui::dpi_x(472),
                height: gui::dpi_y(196),
                control_style: co::ES::MULTILINE
                    | co::ES::READONLY
                    | co::ES::AUTOVSCROLL
                    | co::ES::AUTOHSCROLL,
                window_style: co::WS::CHILD
                    | co::WS::VISIBLE
                    | co::WS::VSCROLL
                    | co::WS::TABSTOP,
                ..Default::default()
            },
        );

        let btn_back = button(&wnd, "上一步", (24, 326), 90);
        let btn_recheck = button(&wnd, "重新检查", (124, 326), 90);
        let btn_next = button(&wnd, "下一步", (406, 326), 90);
        let btn_map = button(&wnd, "开始映射", (306, 326), 90);
        let btn_open = button(&wnd, "打开网盘", (206, 326), 90);
        let btn_finish = button(&wnd, "完成", (406, 326), 90);

        Self {
            wnd,
            state: Rc::new(RefCell::new(State::default())),
            p1_title,
            p1_body,
            p2_title,
            p2_winfsp,
            p2_sshfs,
            p2_keepalive,
            p2_hint,
            p2_note,
            btn_install,
            btn_configure,
            p3_title,
            lbl_user,
            edit_user,
            lbl_pass,
            edit_pass,
            lbl_drive,
            cmb_drive,
            p3_hint,
            p3_error,
            p4_title,
            p4_hint,
            edit_log,
            btn_back,
            btn_recheck,
            btn_next,
            btn_map,
            btn_open,
            btn_finish,
        }
    }

    fn events(&self) {
        let wizard = self.clone();
        self.wnd.on().wm_create(move |_| {
            wizard.fixup_controls();
            wizard.show_page(Page::Welcome);
            Ok(0)
        });

        let wizard = self.clone();
        self.btn_back.on().bn_clicked(move || {
            wizard.go_back();
            Ok(())
        });

        let wizard = self.clone();
        self.btn_next.on().bn_clicked(move || {
            wizard.go_next();
            Ok(())
        });

        let wizard = self.clone();
        self.btn_recheck
            .on()
            .bn_clicked(move || {
                wizard.refresh_deps();
                wizard.add_note("已重新检查组件状态。");
                Ok(())
            });

        let wizard = self.clone();
        self.btn_install.on().bn_clicked(move || {
            wizard.refresh_deps();
            let status = wizard.state.borrow().deps;
            for line in deps::install_missing(&status) {
                wizard.add_note(&line);
            }
            wizard.refresh_deps();
            Ok(())
        });

        let wizard = self.clone();
        self.btn_configure.on().bn_clicked(move || {
            wizard.configure_keepalive();
            Ok(())
        });

        let wizard = self.clone();
        self.btn_map.on().bn_clicked(move || {
            wizard.start_mapping();
            Ok(())
        });

        let wizard = self.clone();
        self.btn_open.on().bn_clicked(move || {
            wizard.open_mapped_drive();
            Ok(())
        });

        let wizard = self.clone();
        self.btn_finish.on().bn_clicked(move || {
            wizard.wnd.close();
            Ok(())
        });
    }

    /// Adjustments that need a live window handle.
    ///
    /// `ComboBoxOpts` has no height field and winsafe creates the control with
    /// zero height, which would collapse the drop-down list, so give it room.
    fn fixup_controls(&self) {
        let _ = self.cmb_drive.hwnd().MoveWindow(
            w::POINT::with(gui::dpi_x(24), gui::dpi_y(206)),
            w::SIZE::with(gui::dpi_x(120), gui::dpi_y(200)),
            true,
        );
    }

    fn show_page(&self, page: Page) {
        if page == Page::Deps {
            // Refresh immediately so the "下一步" state matches reality.
            self.refresh_deps();
        }

        {
            let mut state = self.state.borrow_mut();
            state.page = page;
            if page == Page::Map {
                state.mapped = false;
                state.log.clear();
            }
        }

        let set = |hwnd: &w::HWND, visible: bool| {
            let _ = hwnd.ShowWindow(if visible { co::SW::SHOW } else { co::SW::HIDE });
        };

        let welcome = page == Page::Welcome;
        set(self.p1_title.hwnd(), welcome);
        set(self.p1_body.hwnd(), welcome);

        let deps_page = page == Page::Deps;
        set(self.p2_title.hwnd(), deps_page);
        set(self.p2_winfsp.hwnd(), deps_page);
        set(self.p2_sshfs.hwnd(), deps_page);
        set(self.p2_keepalive.hwnd(), deps_page);
        set(self.p2_hint.hwnd(), deps_page);
        set(self.p2_note.hwnd(), deps_page);
        set(self.btn_install.hwnd(), deps_page);
        set(self.btn_configure.hwnd(), deps_page);

        let account = page == Page::Account;
        set(self.p3_title.hwnd(), account);
        set(self.lbl_user.hwnd(), account);
        set(self.edit_user.hwnd(), account);
        set(self.lbl_pass.hwnd(), account);
        set(self.edit_pass.hwnd(), account);
        set(self.lbl_drive.hwnd(), account);
        set(self.cmb_drive.hwnd(), account);
        set(self.p3_hint.hwnd(), account);
        set(self.p3_error.hwnd(), account);

        let map_page = page == Page::Map;
        set(self.p4_title.hwnd(), map_page);
        set(self.p4_hint.hwnd(), map_page);
        set(self.edit_log.hwnd(), map_page);

        if map_page {
            let _ = self.edit_log.hwnd().SetWindowText("");
        }

        self.update_nav();

        if account {
            let _ = self.edit_user.hwnd().SetFocus();
        } else if map_page {
            let _ = self.btn_map.hwnd().SetFocus();
        }
    }

    fn update_nav(&self) {
        let (page, mapped) = {
            let state = self.state.borrow();
            (state.page, state.mapped)
        };

        let set = |hwnd: &w::HWND, visible: bool| {
            let _ = hwnd.ShowWindow(if visible { co::SW::SHOW } else { co::SW::HIDE });
        };

        set(self.btn_back.hwnd(), page != Page::Welcome);
        set(self.btn_recheck.hwnd(), page == Page::Deps);
        set(
            self.btn_next.hwnd(),
            matches!(page, Page::Welcome | Page::Deps | Page::Account),
        );
        set(self.btn_map.hwnd(), page == Page::Map);
        set(self.btn_open.hwnd(), page == Page::Map);
        set(self.btn_finish.hwnd(), page == Page::Map);

        let next_enabled = match page {
            Page::Deps => self.state.borrow().deps.ready(),
            _ => true,
        };
        let _ = self.btn_next.hwnd().EnableWindow(next_enabled);
        let _ = self.btn_map.hwnd().EnableWindow(!mapped);
        let _ = self.btn_open.hwnd().EnableWindow(mapped);
    }

    fn go_back(&self) {
        let page = self.state.borrow().page;
        let previous = match page {
            Page::Welcome => Page::Welcome,
            Page::Deps => Page::Welcome,
            Page::Account => Page::Deps,
            Page::Map => Page::Account,
        };
        self.show_page(previous);
    }

    fn go_next(&self) {
        let page = self.state.borrow().page;
        match page {
            Page::Welcome => self.show_page(Page::Deps),
            Page::Deps => {
                self.refresh_deps();
                if self.state.borrow().deps.ready() {
                    self.show_page(Page::Account);
                } else {
                    self.add_note("仍有组件未安装，请先完成安装并重新检查。");
                }
            }
            Page::Account => {
                if self.account_values().is_some() {
                    self.show_page(Page::Map);
                }
            }
            Page::Map => {}
        }
    }

    fn refresh_deps(&self) {
        let status = deps::check();
        self.state.borrow_mut().deps = status;

        set_label(
            &self.p2_winfsp,
            &format!("WinFsp：{}（WinFsp 文件系统驱动）", status_text(status.winfsp)),
        );
        set_label(
            &self.p2_sshfs,
            &format!("SSHFS-Win：{}（SSH 文件系统服务）", status_text(status.sshfs)),
        );
        set_label(
            &self.p2_keepalive,
            &format!("断线重连参数：{}", keepalive_text(status.keepalive)),
        );

        self.update_nav();
    }

    fn add_note(&self, line: &str) {
        let text = {
            let mut state = self.state.borrow_mut();
            state.notes.push(line.to_owned());
            // Keep the label readable: show the most recent entries only.
            let start = state.notes.len().saturating_sub(4);
            state.notes[start..].join("\r\n")
        };
        set_label(&self.p2_note, &text);
    }

    fn account_values(&self) -> Option<(String, String, String)> {
        let user = self
            .edit_user
            .text()
            .unwrap_or_default()
            .trim()
            .to_owned();
        let password = self.edit_pass.text().unwrap_or_default();
        let drive = self
            .cmb_drive
            .items()
            .selected_text()
            .ok()
            .flatten()
            .unwrap_or_default();

        let error = if user.is_empty() {
            "请填写 AIDesk 用户名。"
        } else if password.is_empty() {
            "请填写密码。"
        } else if drive.is_empty() {
            "请选择要映射的盘符。"
        } else {
            set_label(&self.p3_error, "");
            return Some((user, password, drive));
        };

        set_label(&self.p3_error, error);
        None
    }

    fn configure_keepalive(&self) {
        match registry::configure_keepalive() {
            registry::ConfigureOutcome::Applied => {
                self.add_note("已写入断线自动重连参数。");
            }
            registry::ConfigureOutcome::AlreadyApplied => {
                self.add_note("断线自动重连参数已是最新，无需修改。");
            }
            registry::ConfigureOutcome::NeedsElevation => {
                match registry::request_elevated_configure() {
                    Ok(()) => self.add_note(
                        "已请求管理员权限写入重连参数；授权完成后请点击“重新检查”。",
                    ),
                    Err(err) => self.add_note(&format!("无法请求管理员权限：{err}")),
                }
            }
            registry::ConfigureOutcome::Failed(message) => {
                self.add_note(&message);
            }
        }
        self.refresh_deps();
    }

    fn clear_log(&self) {
        self.state.borrow_mut().log.clear();
        let _ = self.edit_log.hwnd().SetWindowText("");
    }

    /// Appends one line to the read-only log box.
    fn log(&self, line: &str) {
        let text = {
            let mut state = self.state.borrow_mut();
            state.log.push(line.to_owned());
            state.log.join("\r\n")
        };
        let _ = self.edit_log.hwnd().SetWindowText(&text);
        let _ = self.edit_log.hwnd().UpdateWindow();
        let _ = self.wnd.hwnd().UpdateWindow();
    }

    fn start_mapping(&self) {
        if self.state.borrow().mapped {
            return;
        }

        let Some((user, password, drive)) = self.account_values() else {
            return;
        };

        self.clear_log();
        self.log(&format!("开始映射 {drive} → \\\\sshfs\\{user}@{SERVER}"));

        match registry::configure_keepalive() {
            registry::ConfigureOutcome::Applied => self.log("已写入断线自动重连参数。"),
            registry::ConfigureOutcome::AlreadyApplied => {
                self.log("断线自动重连参数已是最新。")
            }
            registry::ConfigureOutcome::NeedsElevation => {
                match registry::request_elevated_configure() {
                    Ok(()) => self.log(
                        "已请求管理员权限写入重连参数；请在授权完成后点击“重新检查”。",
                    ),
                    Err(err) => self.log(&format!("无法请求管理员权限：{err}")),
                }
            }
            registry::ConfigureOutcome::Failed(message) => {
                self.log(&format!("重连参数写入失败：{message}"))
            }
        }

        let _ = self.wnd.hwnd().UpdateWindow();

        let outcome = mapping::map_drive(&drive, &user, &password);
        for line in outcome.log {
            self.log(&line);
        }

        if outcome.ok {
            self.state.borrow_mut().mapped = true;
            self.log("全部完成，可点击“打开网盘”查看。");
        } else {
            self.log("映射未完成，请根据上面的提示处理后重试。");
        }

        self.update_nav();
        let _ = self.btn_finish.hwnd().SetFocus();
    }

    fn open_mapped_drive(&self) {
        let Some(drive) = self
            .cmb_drive
            .items()
            .selected_text()
            .ok()
            .flatten()
            .filter(|_| self.state.borrow().mapped)
        else {
            return;
        };

        if let Err(err) = win32::shell_execute("open", "explorer.exe", &format!("{drive}\\")) {
            win32::error_box(&format!("无法打开 {drive}：{err}"));
        }
    }
}

fn set_label(label: &gui::Label, text: &str) {
    let _ = label.hwnd().SetWindowText(text);
}
