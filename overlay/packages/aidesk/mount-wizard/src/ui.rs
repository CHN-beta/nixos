//! The two-page wizard UI.
//!
//! Page 1 is the introduction; page 2 is a four-row setup table. Both pages
//! live on one fixed-size main window and every control is created up front,
//! then shown or hidden per page, which keeps navigation trivial and avoids
//! re-creating native windows on every step. The account form of row 4 lives in
//! a [`gui::WindowModal`] that is created on demand and closed as soon as the
//! drive is mapped.

use std::cell::{Cell, RefCell};
use std::rc::Rc;

use winsafe::{self as w, co, gui, prelude::*};

use crate::{deps, mapping, registry, win32};

pub const WIN_TITLE: &str = "AIDesk 网盘助手";

// Page 1
pub const P1_TITLE: &str = "欢迎使用 AIDesk 网盘助手";
pub const P1_BODY: &str = "本工具将把您的 AIDesk 云端个人目录，直接添加为电脑里的一个本地盘符。\r\n\r\n\
设置完成后开机自动连接，您可以像使用普通本地硬盘或 U 盘一样直接打开和保存文件。\r\n\r\n\
文件实时保存在云端，跨设备随时访问，安全便捷。\r\n\r\n\
请点击“下一步”开始简单的准备与连接设置。";
pub const BTN_NEXT: &str = "下一步";
pub const BTN_CANCEL: &str = "取消";

// Page 2
pub const P2_TITLE: &str = "环境准备与网盘挂载";
pub const P2_HINT: &str = "请按自上而下的顺序依次完成以下 4 项操作，全部完成后点击“完成”退出向导。";
pub const BTN_BACK: &str = "上一步";
pub const BTN_RECHECK: &str = "重新检查";
pub const BTN_FINISH: &str = "完成";

// Row 1
pub const ITEM1_NAME: &str = "虚拟磁盘驱动";
pub const ITEM1_DESC: &str = "让电脑能够像本地磁盘一样读写云端文件。";
pub const ITEM1_UNREADY: &str = "未安装";
pub const ITEM1_READY: &str = "已安装";
pub const ITEM1_DO: &str = "安装";
pub const ITEM1_UNDO: &str = "卸载";

// Row 2
pub const ITEM2_NAME: &str = "远程连接组件";
pub const ITEM2_DESC: &str = "连接云端服务器，保障文件安全稳定传输。";
pub const ITEM2_UNREADY: &str = "未安装";
pub const ITEM2_READY: &str = "已安装";
pub const ITEM2_DO: &str = "安装";
pub const ITEM2_UNDO: &str = "卸载";

// Row 3
pub const ITEM3_NAME: &str = "断线自动重连";
pub const ITEM3_DESC: &str = "网络波动时后台自动恢复，保持网盘连接。";
pub const ITEM3_UNREADY: &str = "未启用";
pub const ITEM3_READY: &str = "已启用";
pub const ITEM3_DO: &str = "启用";
pub const ITEM3_UNDO: &str = "关闭";

// Row 4
pub const ITEM4_NAME: &str = "挂载云端网盘";
pub const ITEM4_DESC: &str = "登录个人账号，将云端空间挂载为本地盘符。";
pub const ITEM4_UNREADY: &str = "未挂载";
pub const ITEM4_DO: &str = "配置";
pub const ITEM4_UNDO: &str = "断开";

// Modal dialog
pub const DLG_TITLE: &str = "设置与挂载云端网盘";
pub const DLG_LBL_USER: &str = "用户名：";
pub const DLG_LBL_PASS: &str = "密码：";
pub const DLG_LBL_DRIVE: &str = "选择盘符：";
pub const DLG_HINT_SECURE: &str =
    "您的密码将安全保存在本机凭据中，开机登录后将自动连接此网盘。";
pub const DLG_BTN_CONNECT: &str = "确定挂载";
pub const DLG_BTN_CANCEL: &str = "取消";

/// Page-2 table headers, left to right.
const COLUMNS: [&str; 4] = ["项目", "简介", "当前状态", "操作"];

/// Left edge and width of each table column, in unscaled pixels.
const COLUMN_GEOMETRY: [(i32, i32); 4] = [(28, 96), (128, 264), (400, 104), (512, 80)];

/// Top edge of the four table rows, in unscaled pixels.
const ROW_TOP: [i32; 4] = [120, 156, 192, 228];

/// Status text color for a completed setup item. Dark green, so it stays
/// legible on the light `BTNFACE` window background.
const STATUS_READY_COLOR: w::COLORREF = w::COLORREF::from_rgb(0x0b, 0x6b, 0x1f);

/// Status text color for a setup item that still needs attention. Dark red,
/// readable against the same light background.
const STATUS_UNREADY_COLOR: w::COLORREF = w::COLORREF::from_rgb(0xb3, 0x1b, 0x1b);

/// The texts of one setup row.
struct Row {
    name: &'static str,
    desc: &'static str,
    unready: &'static str,
    ready: &'static str,
    action: &'static str,
    undo: &'static str,
}

/// The four setup rows, in the order the user has to complete them.
const ROWS: [Row; 4] = [
    Row {
        name: ITEM1_NAME,
        desc: ITEM1_DESC,
        unready: ITEM1_UNREADY,
        ready: ITEM1_READY,
        action: ITEM1_DO,
        undo: ITEM1_UNDO,
    },
    Row {
        name: ITEM2_NAME,
        desc: ITEM2_DESC,
        unready: ITEM2_UNREADY,
        ready: ITEM2_READY,
        action: ITEM2_DO,
        undo: ITEM2_UNDO,
    },
    Row {
        name: ITEM3_NAME,
        desc: ITEM3_DESC,
        unready: ITEM3_UNREADY,
        ready: ITEM3_READY,
        action: ITEM3_DO,
        undo: ITEM3_UNDO,
    },
    Row {
        name: ITEM4_NAME,
        desc: ITEM4_DESC,
        unready: ITEM4_UNREADY,
        // Row 4 has no static ready text: it shows the attached drive letter.
        ready: "",
        action: ITEM4_DO,
        undo: ITEM4_UNDO,
    },
];

#[derive(Clone, Copy, PartialEq, Eq)]
enum Page {
    Welcome,
    Setup,
}

#[derive(Default)]
struct State {
    deps: deps::Status,
    /// Drive letter of the current SSHFS mapping, e.g. `"Z:"`.
    mounted_drive: Option<String>,
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
    p2_hint: gui::Label,
    p2_status: gui::Label,
    col_headers: [gui::Label; 4],
    item_name: [gui::Label; 4],
    item_desc: [gui::Label; 4],
    item_status: [gui::Label; 4],
    item_button: [gui::Button; 4],

    // Navigation bar
    btn_next: gui::Button,
    btn_back: gui::Button,
    btn_recheck: gui::Button,
    btn_finish: gui::Button,
    btn_cancel: gui::Button,
}

pub fn run() -> Result<(), Box<dyn std::error::Error + Send + Sync>> {
    crate::log::line(format!(
        "启动图形界面，日志文件：{}",
        crate::log::path().display()
    ));
    let wizard = Wizard::new();
    wizard.events();
    let _ = wizard.wnd.run_main(None)?;
    crate::log::line("图形界面已退出。");
    Ok(())
}

fn label(
    parent: &(impl GuiParent + 'static),
    text: &str,
    pos: (i32, i32),
    size: (i32, i32),
) -> gui::Label {
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

fn button(
    parent: &(impl GuiParent + 'static),
    text: &str,
    pos: (i32, i32),
    width: i32,
    height: i32,
) -> gui::Button {
    gui::Button::new(
        parent,
        gui::ButtonOpts {
            text,
            position: gui::dpi(pos.0, pos.1),
            width: gui::dpi_x(width),
            height: gui::dpi_y(height),
            ..Default::default()
        },
    )
}

fn edit(
    parent: &(impl GuiParent + 'static),
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

/// Free drive letters, highest first, plus the index of the default selection.
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

impl Wizard {
    fn new() -> Self {
        let wnd = gui::WindowMain::new(gui::WindowMainOpts {
            title: WIN_TITLE,
            size: gui::dpi(620, 380),
            ..Default::default()
        });

        let p1_title = label(&wnd, P1_TITLE, (28, 24), (564, 28));
        let p1_body = label(&wnd, P1_BODY, (28, 64), (564, 236));

        let p2_title = label(&wnd, P2_TITLE, (28, 22), (564, 26));
        let p2_hint = label(&wnd, P2_HINT, (28, 56), (564, 20));
        let col_headers = std::array::from_fn(|column| {
            let (x, width) = COLUMN_GEOMETRY[column];
            label(&wnd, COLUMNS[column], (x, 88), (width, 20))
        });
        let item_name = std::array::from_fn(|row| {
            let (x, width) = COLUMN_GEOMETRY[0];
            label(&wnd, ROWS[row].name, (x, ROW_TOP[row]), (width, 22))
        });
        let item_desc = std::array::from_fn(|row| {
            let (x, width) = COLUMN_GEOMETRY[1];
            label(&wnd, ROWS[row].desc, (x, ROW_TOP[row]), (width, 22))
        });
        let item_status = std::array::from_fn(|row| {
            let (x, width) = COLUMN_GEOMETRY[2];
            label(&wnd, ROWS[row].unready, (x, ROW_TOP[row]), (width, 22))
        });
        let item_button = std::array::from_fn(|row| {
            let (x, width) = COLUMN_GEOMETRY[3];
            button(
                &wnd,
                ROWS[row].action,
                (x, ROW_TOP[row] - 2),
                width,
                26,
            )
        });
        let p2_status = label(&wnd, "", (28, 266), (564, 40));

        let btn_next = button(&wnd, BTN_NEXT, (380, 336), 100, 28);
        let btn_back = button(&wnd, BTN_BACK, (28, 336), 100, 28);
        let btn_recheck = button(&wnd, BTN_RECHECK, (140, 336), 100, 28);
        let btn_finish = button(&wnd, BTN_FINISH, (380, 336), 100, 28);
        let btn_cancel = button(&wnd, BTN_CANCEL, (492, 336), 100, 28);

        Self {
            wnd,
            state: Rc::new(RefCell::new(State::default())),
            p1_title,
            p1_body,
            p2_title,
            p2_hint,
            p2_status,
            col_headers,
            item_name,
            item_desc,
            item_status,
            item_button,
            btn_next,
            btn_back,
            btn_recheck,
            btn_finish,
            btn_cancel,
        }
    }

    fn events(&self) {
        let wizard = self.clone();
        self.wnd.on().wm_create(move |_| {
            // Probe the machine once up front, so the table is already
            // accurate when page 2 is first shown.
            wizard.refresh();
            wizard.show_page(Page::Welcome);
            Ok(0)
        });

        // Status cells are static controls, so their text color must be set
        // on every `WM_CTLCOLORSTATIC` rather than on the control itself.
        // The color follows `row_ready`, the same predicate that picks the
        // status text, so the two can never disagree.
        //
        // The transparent background mode and the button-face background are
        // applied to *every* static control of the window, not only the status
        // cells: otherwise the plain labels (“虚拟磁盘驱动” etc.) keep the
        // default white control background and stand out as white boxes on the
        // grey dialog surface.
        let wizard = self.clone();
        self.wnd.on().wm_ctl_color_static(move |p| {
            let _ = p.hdc.SetBkMode(co::BKMODE::TRANSPARENT);
            let _ = p.hdc.SetBkColor(w::GetSysColor(co::COLOR::BTNFACE));

            for (row, label) in wizard.item_status.iter().enumerate() {
                if p.hwnd.ptr() == label.hwnd().ptr() {
                    let color = if wizard.row_ready(row) {
                        STATUS_READY_COLOR
                    } else {
                        STATUS_UNREADY_COLOR
                    };
                    let _ = p.hdc.SetTextColor(color);
                    break;
                }
            }

            Ok(w::HBRUSH::GetSysColorBrush(co::COLOR::BTNFACE)?)
        });

        let wizard = self.clone();
        self.btn_next.on().bn_clicked(move || {
            wizard.show_page(Page::Setup);
            Ok(())
        });

        let wizard = self.clone();
        self.btn_back.on().bn_clicked(move || {
            wizard.show_page(Page::Welcome);
            Ok(())
        });

        let wizard = self.clone();
        self.btn_recheck.on().bn_clicked(move || {
            wizard.refresh();
            wizard.set_status("已重新检查各项状态。");
            Ok(())
        });

        let wizard = self.clone();
        self.btn_finish.on().bn_clicked(move || {
            wizard.wnd.close();
            Ok(())
        });

        let wizard = self.clone();
        self.btn_cancel.on().bn_clicked(move || {
            wizard.wnd.close();
            Ok(())
        });

        for row in 0..ROWS.len() {
            let wizard = self.clone();
            self.item_button[row].on().bn_clicked(move || {
                wizard.run_row_action(row);
                Ok(())
            });
        }
    }

    /// Shows `page` and hides every control that does not belong to it.
    fn show_page(&self, page: Page) {
        if page == Page::Setup {
            self.refresh();
        }

        let welcome = page == Page::Welcome;
        show(&self.p1_title, welcome);
        show(&self.p1_body, welcome);
        show(&self.btn_next, welcome);

        let setup = page == Page::Setup;
        show(&self.p2_title, setup);
        show(&self.p2_hint, setup);
        show(&self.p2_status, setup);
        show(&self.btn_back, setup);
        show(&self.btn_recheck, setup);
        show(&self.btn_finish, setup);
        for control in self
            .col_headers
            .iter()
            .chain(self.item_name.iter())
            .chain(self.item_desc.iter())
            .chain(self.item_status.iter())
        {
            show(control, setup);
        }
        for control in &self.item_button {
            show(control, setup);
        }

        // Cancelling is always possible.
        show(&self.btn_cancel, true);
    }

    /// Re-reads the four setup items and updates statuses, button labels and
    /// the availability of the dependent rows and of "完成".
    fn refresh(&self) {
        let status = deps::check();
        let mounted_drive = mapping::detect_mounted_drive();

        crate::log::line(format!(
            "界面状态刷新：WinFsp={}，SSHFS-Win={}，断线自动重连={}，已挂载盘符={mounted_drive:?}",
            status.winfsp, status.sshfs, status.keepalive
        ));

        {
            let mut state = self.state.borrow_mut();
            state.deps = status;
            state.mounted_drive = mounted_drive.clone();
        }

        for row in 0..3 {
            let is_ready = self.row_ready(row);
            set_text(
                &self.item_status[row],
                pick(is_ready, ROWS[row].ready, ROWS[row].unready),
            );
            set_text(
                &self.item_button[row],
                pick(is_ready, ROWS[row].undo, ROWS[row].action),
            );
        }

        // Row 4 has no static ready text: it shows the attached drive letter.
        set_text(
            &self.item_status[3],
            &match &mounted_drive {
                Some(drive) => format!("已挂载 ({drive})"),
                None => ITEM4_UNREADY.to_owned(),
            },
        );
        set_text(
            &self.item_button[3],
            pick(self.row_ready(3), ROWS[3].undo, ROWS[3].action),
        );

        // Each row depends on the rows above it: nothing can be connected
        // before the driver is installed, and nothing can be mounted before
        // the connection component and the keepalive are set up.
        let sshfs_row_ready = status.winfsp;
        let keepalive_row_ready = status.ready();
        let mount_row_ready = keepalive_row_ready && status.keepalive;
        enable(&self.item_button[1], sshfs_row_ready);
        enable(&self.item_button[2], keepalive_row_ready);
        enable(&self.item_button[3], mount_row_ready);

        enable(
            &self.btn_finish,
            mount_row_ready && mounted_drive.is_some(),
        );
    }

    /// Whether the setup row is currently in its completed state. Both the
    /// status text and its color derive from this, so they stay consistent.
    fn row_ready(&self, row: usize) -> bool {
        let state = self.state.borrow();
        match row {
            0 => state.deps.winfsp,
            1 => state.deps.sshfs,
            2 => state.deps.keepalive,
            _ => state.mounted_drive.is_some(),
        }
    }

    fn set_status(&self, text: &str) {
        set_text(&self.p2_status, text);
        // Paint right away: an installer or an elevation prompt blocks the
        // message loop, so a merely posted `WM_PAINT` would not arrive until
        // everything is over.
        let _ = self.p2_status.hwnd().UpdateWindow();
        let _ = self.wnd.hwnd().UpdateWindow();
    }

    fn run_row_action(&self, row: usize) {
        match row {
            0 | 1 => self.toggle_component(row),
            2 => self.toggle_keepalive(),
            _ => self.toggle_mount(),
        }
    }

    /// Installs or uninstalls WinFsp (row 1) / SSHFS-Win (row 2).
    fn toggle_component(&self, row: usize) {
        let installed = {
            let state = self.state.borrow();
            if row == 0 {
                state.deps.winfsp
            } else {
                state.deps.sshfs
            }
        };
        let name = ROWS[row].name;

        // A second click while the installer runs would start a second MSI
        // instance, so the button stays disabled until `refresh` runs again.
        enable(&self.item_button[row], false);
        self.set_status(&if installed {
            format!("正在卸载{name}，请在卸载向导中完成操作……")
        } else {
            format!("正在安装{name}，请在安装向导中完成操作……")
        });

        let result = match (row, installed) {
            (0, true) => deps::uninstall_winfsp(),
            (0, false) => deps::install_winfsp(),
            (_, true) => deps::uninstall_sshfs(),
            (_, false) => deps::install_sshfs(),
        };

        self.refresh();

        let now = {
            let state = self.state.borrow();
            if row == 0 {
                state.deps.winfsp
            } else {
                state.deps.sshfs
            }
        };
        let message = match result {
            Ok(()) if now != installed => {
                format!("{name}{}。", if now { "已安装" } else { "已卸载" })
            }
            Ok(()) => format!("安装程序已结束，但尚未检测到{name}，请稍后点击“重新检查”。"),
            Err(err) => err,
        };
        self.set_status(&message);
    }

    /// Enables or disables the keepalive options (row 3).
    fn toggle_keepalive(&self) {
        let configured = self.state.borrow().deps.keepalive;

        enable(&self.item_button[2], false);
        self.set_status(if configured {
            "正在关闭断线自动重连（可能需要管理员授权）……"
        } else {
            "正在启用断线自动重连（可能需要管理员授权）……"
        });

        let result = if configured {
            disable_keepalive()
        } else {
            enable_keepalive()
        };

        self.refresh();

        let now = self.state.borrow().deps.keepalive;
        let message = match result {
            Ok(()) if now == !configured => {
                format!("{}。", pick(now, ITEM3_READY, ITEM3_UNREADY))
            }
            Ok(()) => "注册表已更新，但状态未发生变化，请点击“重新检查”。".to_owned(),
            Err(err) => err,
        };
        self.set_status(&message);
    }

    /// Maps the drive through the modal dialog (row 4), or unmaps it.
    fn toggle_mount(&self) {
        if self.state.borrow().mounted_drive.is_some() {
            self.unmount();
        } else {
            self.open_mount_dialog();
        }
    }

    fn open_mount_dialog(&self) {
        let dialog = MountDialog::new();
        if let Err(err) = dialog.dlg.show_modal(&self.wnd) {
            win32::error_box(&format!("无法打开挂载设置窗口：{err}"));
            return;
        }

        if dialog.mounted.get() {
            // Row 4 now shows the attached drive and "完成" becomes clickable.
            self.refresh();
            self.set_status("");
        }
    }

    fn unmount(&self) {
        let Some(drive) = self.state.borrow().mounted_drive.clone() else {
            return;
        };

        enable(&self.item_button[3], false);
        self.set_status(&format!("正在断开 {drive}……"));

        let result = mapping::unmap_drive(&drive);

        self.refresh();

        let message = match result {
            Ok(()) if self.state.borrow().mounted_drive.is_none() => {
                format!("{drive} 已断开。")
            }
            Ok(()) => "连接仍未断开，请稍后点击“重新检查”。".to_owned(),
            Err(err) => err,
        };
        self.set_status(&message);
    }
}

/// The modal account dialog opened by the fourth row.
#[derive(Clone)]
struct MountDialog {
    dlg: gui::WindowModal,
    edit_user: gui::Edit,
    edit_pass: gui::Edit,
    cmb_drive: gui::ComboBox,
    lbl_status: gui::Label,
    btn_connect: gui::Button,
    btn_cancel: gui::Button,
    /// Set to `true` once a mapping was established.
    mounted: Rc<Cell<bool>>,
}

impl MountDialog {
    fn new() -> Self {
        let dlg = gui::WindowModal::new(gui::WindowModalOpts {
            title: DLG_TITLE,
            size: gui::dpi(380, 260),
            ..Default::default()
        });

        // The hint is destroyed together with the dialog; there is no need to
        // keep a handle to it.
        let _ = label(&dlg, DLG_LBL_USER, (24, 26), (76, 20));
        let edit_user = edit(&dlg, (108, 22), 248, 24, false);
        let _ = label(&dlg, DLG_LBL_PASS, (24, 62), (76, 20));
        let edit_pass = edit(&dlg, (108, 58), 248, 24, true);
        let _ = label(&dlg, DLG_LBL_DRIVE, (24, 98), (76, 20));

        let (drives, default_index) = available_drives();
        let drive_refs: Vec<&str> = drives.iter().map(String::as_str).collect();
        let cmb_drive = gui::ComboBox::new(
            &dlg,
            gui::ComboBoxOpts {
                position: gui::dpi(108, 94),
                width: gui::dpi_x(120),
                items: &drive_refs,
                selected_item: Some(default_index as u32),
                ..Default::default()
            },
        );

        let _ = label(&dlg, DLG_HINT_SECURE, (24, 128), (332, 40));
        let lbl_status = label(&dlg, "", (24, 172), (332, 36));
        let btn_connect = button(&dlg, DLG_BTN_CONNECT, (156, 216), 100, 26);
        let btn_cancel = button(&dlg, DLG_BTN_CANCEL, (268, 216), 88, 26);

        let dialog = Self {
            dlg,
            edit_user,
            edit_pass,
            cmb_drive,
            lbl_status,
            btn_connect,
            btn_cancel,
            mounted: Rc::new(Cell::new(false)),
        };
        dialog.events();
        dialog
    }

    fn events(&self) {
        // The modal dialog uses the same plain static labels as the main
        // window, so it needs the same transparent background treatment;
        // otherwise every label shows as a white box on the grey dialog.
        self.dlg.on().wm_ctl_color_static(|p| {
            let _ = p.hdc.SetBkMode(co::BKMODE::TRANSPARENT);
            let _ = p.hdc.SetBkColor(w::GetSysColor(co::COLOR::BTNFACE));
            Ok(w::HBRUSH::GetSysColorBrush(co::COLOR::BTNFACE)?)
        });

        // `ComboBoxOpts` has no height field and winsafe creates the control
        // with zero height, which would collapse the drop-down list, so give it
        // room before the first paint.
        let dialog = self.clone();
        self.dlg.on().wm_create(move |_| {
            let _ = dialog.cmb_drive.hwnd().MoveWindow(
                w::POINT::with(gui::dpi_x(108), gui::dpi_y(94)),
                w::SIZE::with(gui::dpi_x(248), gui::dpi_y(200)),
                true,
            );
            let _ = dialog.edit_user.hwnd().SetFocus();
            Ok(0)
        });

        let dialog = self.clone();
        self.btn_connect.on().bn_clicked(move || {
            dialog.connect();
            Ok(())
        });

        let dialog = self.clone();
        self.btn_cancel.on().bn_clicked(move || {
            dialog.dlg.close();
            Ok(())
        });
    }

    /// Validates the form, maps the drive and closes the dialog on success.
    ///
    /// A failure keeps the dialog (and the typed password) open, so the user
    /// can correct the account and retry without starting over.
    fn connect(&self) {
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

        if user.is_empty() {
            self.set_status("请填写用户名。");
            let _ = self.edit_user.hwnd().SetFocus();
            return;
        }
        if password.is_empty() {
            self.set_status("请填写密码。");
            let _ = self.edit_pass.hwnd().SetFocus();
            return;
        }
        if drive.is_empty() {
            self.set_status("请选择盘符。");
            return;
        }

        self.set_status("正在连接云端网盘，请稍候…");
        enable(&self.btn_connect, false);

        crate::log::line(format!(
            "挂载对话框提交：drive={drive:?}，username={user:?}，password_len={}",
            password.len()
        ));

        let outcome = mapping::map_drive(&drive, &user, &password);
        if outcome.ok {
            self.mounted.set(true);
            self.dlg.close();
            return;
        }

        enable(&self.btn_connect, true);
        let failure = outcome
            .log
            .iter()
            .rev()
            .find(|line| line.starts_with("映射失败"))
            .or_else(|| outcome.log.last())
            .cloned()
            .unwrap_or_else(|| "映射失败。".to_owned());
        let log_file = outcome
            .log
            .iter()
            .rev()
            .find(|line| line.starts_with("日志文件："))
            .cloned()
            .unwrap_or_else(|| format!("日志文件：{}", crate::log::path().display()));
        self.set_status(&format!(
            "{failure} 请检查用户名和密码后重试。\r\n{log_file}"
        ));
    }

    fn set_status(&self, text: &str) {
        set_text(&self.lbl_status, text);
        let _ = self.lbl_status.hwnd().UpdateWindow();
        let _ = self.dlg.hwnd().UpdateWindow();
    }
}

fn enable_keepalive() -> Result<(), String> {
    match registry::configure_keepalive() {
        registry::ApplyOutcome::Applied | registry::ApplyOutcome::AlreadyApplied => Ok(()),
        registry::ApplyOutcome::NeedsElevation => registry::request_elevated_configure(),
        registry::ApplyOutcome::Failed(message) => Err(message),
    }
}

fn disable_keepalive() -> Result<(), String> {
    match registry::unconfigure_keepalive() {
        registry::ApplyOutcome::Applied | registry::ApplyOutcome::AlreadyApplied => Ok(()),
        registry::ApplyOutcome::NeedsElevation => registry::request_elevated_unconfigure(),
        registry::ApplyOutcome::Failed(message) => Err(message),
    }
}

/// `ready_text` when `ready`, `unready_text` otherwise.
fn pick<'a>(ready: bool, ready_text: &'a str, unready_text: &'a str) -> &'a str {
    if ready {
        ready_text
    } else {
        unready_text
    }
}

fn set_text(control: &impl GuiWindow, text: &str) {
    let _ = control.hwnd().SetWindowText(text);
}

fn show(control: &impl GuiWindow, visible: bool) {
    let _ = control
        .hwnd()
        .ShowWindow(if visible { co::SW::SHOW } else { co::SW::HIDE });
}

fn enable(control: &impl GuiWindow, enabled: bool) {
    let _ = control.hwnd().EnableWindow(enabled);
}
