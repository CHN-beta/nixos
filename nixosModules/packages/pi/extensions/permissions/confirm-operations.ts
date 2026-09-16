import { request, type PermissionsAPI } from "@thurstonsand/pi-permissions";

// Loaded by pi-permissions, NOT by Pi's extension loader.
export default function permissions(api: PermissionsAPI) {
  api.onToolUse({
    name: "Confirm execution and external tools",
    description: "Review shell commands, file mutations, delegation and external tool calls before execution.",
    handler({ tool }) {
      if (["read", "grep", "find", "ls", "question", "todo"].includes(tool.toolName)) return;
      return request({
        guidance: "Check the full arguments and target. Approving delegation or an MCP dispatcher does not individually approve or inspect its nested operations. Ctrl+S disables this check for the session branch.",
      });
    },
  });
}
