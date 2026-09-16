# Agent-Browser 使用注意事项 (MCP Server)

## 上下文与参数一致性 (Context & Arguments Consistency)

当通过 MCP 调用 `agent-browser` 相关的工具时，如果使用了 `extraArgs`（例如设置代理 `--proxy socks5://...` 或开启前台界面 `--headed`），**必须确保在后续对该页面的所有操作调用中（如 `get_text`、`click`、`eval` 等），均传入完全相同的 `extraArgs` 数组**。

**原因：**
后台进程（Daemon）是根据传入的启动参数来区分和隔离浏览器上下文（Context）的。如果在后续调用中遗漏了 `extraArgs`，Daemon 会认为参数不匹配，从而自动切回（或新建）一个没有任何特殊参数的默认上下文。这会导致当前操作的页面突然变成 `about:blank`，从而导致抓取失败或返回空数据 `(no output)`。

**正确调用流程示例：**
1. `agent_browser_open { url: "...", extraArgs: ["--proxy", "socks5://127.0.0.1:10882", "--headed"] }`
2. `agent_browser_get_text { selector: "body", extraArgs: ["--proxy", "socks5://127.0.0.1:10882", "--headed"] }`
3. `agent_browser_click { selector: "#submit", extraArgs: ["--proxy", "socks5://127.0.0.1:10882", "--headed"] }`

**错误示例（会导致页面重置为 about:blank）：**
1. `agent_browser_open { url: "...", extraArgs: ["--proxy", "socks5://127.0.0.1:10882"] }`
2. `agent_browser_get_text { selector: "body" }`  <-- 遗漏了 extraArgs，发生上下文切换，页面丢失。

## 学术论文付费墙与代理使用技巧 (Paywall & Proxy Timeout Handling)

在通过浏览器下载或访问学术论文时：
1. **应对付费墙**：如果遇到需要购买、订阅或要求机构访问权限的付费墙（Paywall），请尝试重新打开浏览器并使用专属代理：`socks5://srv2-node0.ts.chn.moe:10882`。该代理通常能提供机构访问权限，从而解锁 "Download PDF" 等下载选项。
2. **处理页面加载超时**：使用该代理访问外网资源时，经常会遇到页面加载超时（如返回 `Operation timed out` 或 `Tool execution aborted`）的情况。这通常是因为部分第三方脚本或广告资源被墙或加载过慢。**遇到超时请直接尝试继续操作，不要放弃或重开页面**，因为网页的核心 DOM 结构（如文本和下载按钮）通常已经加载完毕。您可以继续使用 `snapshot` 分析页面元素或进行 `click` 等交互操作。
