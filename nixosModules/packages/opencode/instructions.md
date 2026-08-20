## Camoufox MCP Guidelines
当你尝试调用任何 Camoufox 相关的 MCP 工具时，如果收到包含 `"code":"CONNECTION_REFUSED"` 或 `"Failed to connect to CamoFox API"` 的错误信息，这意味着本机的 Camoufox 浏览器服务尚未启动。
**遇到此错误时，你必须遵守以下规则：**
1. 绝对不要尝试使用 bash 工具自行运行 `camofox-browser` 命令，因为该命令会持续阻塞终端，导致整个进程卡死。
2. 立即向用户说明情况，并请求用户在另一个独立的终端窗口中手动执行 `camofox-browser` 命令来启动服务。
3. 暂停后续的网页操作计划，直到用户回复确认服务已经启动后，再继续重试工具调用。