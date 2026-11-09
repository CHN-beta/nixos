# AIDesk Agent 开发指南

本文档面向参与 AIDesk 项目开发的 AI Agent，旨在明确项目各模块架构职责及开发规范。

## 1. 核心模块与功能

- **`backend/`**
  基于 Rust (Axum / Tokio / SQLite) 构建的 AIDesk 后端服务。主要职责包括：
  - 管理 `omp` AI 会话 RPC 进程及生命周期。
  - 提供工作区文件与目录操作（CRUD、流式上传、ZIP 打包下载、实时监听）。
  - 提供 Git 状态与 Diff 接口。
  - 维护 Web 终端 PTY 会话。
  - 提供语音转写 (STT) 接口。
  - 管理模型配置与记忆库等 API 服务。

- **`frontend/`**
  基于 React 19 + TypeScript + Vite 构建的 AIDesk Web 前端应用（SPA）。主要界面与交互包括：
  - AI 对话主交互界面。
  - 虚拟滚动资源管理器（File Explorer）。
  - 多模式文件查看器与 CodeMirror 编辑器（File Viewer / Code Editor）。
  - Git 变更面板。
  - Web 终端及通知中心等交互组件。

- **`mount-wizard/`**
  基于 Rust (`winsafe`) 交叉编译的 Windows 桌面端“AIDesk 网盘助手”引导程序。主要功能包括：
  - 内嵌 WinFsp 与 SSHFS-Win 安装包。
  - 帮助 Windows 用户一键检测与安装所需驱动。
  - 配置自动重连与隐藏点文件（`dothidden`）注册表项。
  - 将云端个人工作区挂载为 Windows 本地持久化盘符。

---

## 2. Agent 开发与提交流程规范

所有 Agent 在进行编码任务时，必须严格遵守以下流程：

1. **编写与实现**
   - 接收任务后进行高质量编码实现，严谨遵循系统设计与已有规范。

2. **立即复查**
   - 编码完成后立即全面复查，仔细排查逻辑缺陷、编译错误、遗漏边界情况或不合规实现。

3. **迭代修正与验证**
   - 若复查发现问题，立即返回修改，持续排查与修复，直至确认所有设计目标全部达成且构建/测试通过。

4. **即时原子化提交 (Git Commit)**
   - 每个功能完成并复查无误后，立即执行 `git commit` 提交。
   - 每次提交必须聚焦于单一完整功能，保持清晰、独立的 Git 提交历史。
