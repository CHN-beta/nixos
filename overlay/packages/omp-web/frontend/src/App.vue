<template>
  <div class="flex h-screen w-screen overflow-hidden bg-zinc-950 text-zinc-100 font-sans">
    <!-- Sidebar -->
    <aside class="w-72 bg-zinc-900/80 border-r border-zinc-800 flex flex-col flex-shrink-0 select-none">
      <div class="p-4 border-b border-zinc-800 flex items-center justify-between">
        <div class="flex items-center space-x-2">
          <span class="text-xl font-bold tracking-tight text-amber-500">⌥ omp</span>
          <span class="text-xs px-1.5 py-0.5 rounded bg-zinc-800 text-zinc-400 font-mono">web</span>
        </div>
        <button
          @click="showNewModal = true"
          class="px-2.5 py-1 text-xs font-medium rounded-md bg-amber-600 hover:bg-amber-500 text-white transition flex items-center space-x-1"
        >
          <span>+ New</span>
        </button>
      </div>

      <!-- Sessions List -->
      <div class="flex-1 overflow-y-auto p-2 space-y-1">
        <div v-if="sessions.length === 0" class="p-4 text-center text-xs text-zinc-500">
          No active sessions. Click "+ New" to spawn one.
        </div>
        <div
          v-for="s in sessions"
          :key="s.id"
          @click="selectSession(s.id)"
          :class="[
            'group flex items-center justify-between p-2.5 rounded-lg text-xs cursor-pointer transition',
            activeSessionId === s.id
              ? 'bg-zinc-800 text-zinc-100 font-medium border border-zinc-700/60'
              : 'text-zinc-400 hover:bg-zinc-800/40 hover:text-zinc-200'
          ]"
        >
          <div class="truncate mr-2 flex flex-col min-w-0">
            <span class="truncate font-semibold text-zinc-200">{{ getDirName(s.cwd) }}</span>
            <span class="truncate text-[10px] text-zinc-500 font-mono">{{ s.cwd }}</span>
          </div>
          <button
            @click.stop="closeSession(s.id)"
            class="opacity-0 group-hover:opacity-100 p-1 hover:bg-zinc-700 rounded text-zinc-400 hover:text-rose-400 transition"
            title="Terminate session"
          >
            ✕
          </button>
        </div>
      </div>

      <div class="p-3 border-t border-zinc-800 text-[10px] text-zinc-500 flex justify-between items-center">
        <span>Rust Gateway</span>
        <span class="font-mono text-emerald-500">Online</span>
      </div>
    </aside>

    <!-- Main Workspace -->
    <main class="flex-1 flex flex-col min-w-0 bg-zinc-950">
      <template v-if="activeSession">
        <!-- Session Topbar -->
        <header class="h-12 border-b border-zinc-800 px-4 flex items-center justify-between flex-shrink-0 bg-zinc-900/30">
          <div class="flex items-center space-x-2 truncate">
            <span class="text-xs font-medium text-zinc-300">CWD:</span>
            <span class="text-xs font-mono bg-zinc-800/60 text-amber-400 px-2 py-0.5 rounded border border-zinc-700/40 truncate">
              {{ activeSession.cwd }}
            </span>
          </div>
          <div class="flex items-center space-x-3 text-xs">
            <span class="flex items-center space-x-1.5 font-mono text-[11px]">
              <span :class="['w-2 h-2 rounded-full', isConnected ? 'bg-emerald-500 animate-pulse' : 'bg-rose-500']"></span>
              <span :class="isConnected ? 'text-zinc-400' : 'text-rose-400'">
                {{ isConnected ? 'Connected' : 'Connecting...' }}
              </span>
            </span>
          </div>
        </header>

        <!-- Chat / Stream Messages -->
        <div ref="chatContainer" class="flex-1 overflow-y-auto p-4 space-y-4">
          <div v-if="messages.length === 0" class="h-full flex items-center justify-center text-zinc-600 text-sm">
            Session ready. Send a prompt below to start.
          </div>

          <div
            v-for="(msg, idx) in messages"
            :key="idx"
            :class="['flex flex-col space-y-1', msg.role === 'user' ? 'items-end' : 'items-start']"
          >
            <!-- User Prompt -->
            <div
              v-if="msg.role === 'user'"
              class="max-w-[80%] rounded-2xl px-4 py-2.5 bg-amber-600 text-white text-sm shadow-sm leading-relaxed"
            >
              {{ msg.text }}
            </div>

            <!-- Assistant / Tool / Thinking -->
            <div
              v-else
              class="max-w-[90%] w-full rounded-xl bg-zinc-900 border border-zinc-800 p-4 text-sm text-zinc-200 space-y-3 leading-relaxed shadow-sm"
            >
              <!-- Thinking Section -->
              <details v-if="msg.thinking" class="group bg-zinc-950/60 rounded-lg border border-zinc-800/60 p-2.5 text-xs text-zinc-400">
                <summary class="cursor-pointer font-medium text-zinc-400 hover:text-zinc-300 select-none flex items-center space-x-2">
                  <span class="text-amber-500">💭 Thinking Process</span>
                </summary>
                <div class="mt-2 whitespace-pre-wrap font-mono text-zinc-400 leading-normal border-t border-zinc-800/60 pt-2">
                  {{ msg.thinking }}
                </div>
              </details>

              <!-- Main Content / Markdown -->
              <div v-if="msg.text" class="prose prose-invert max-w-none text-sm break-words" v-html="renderMarkdown(msg.text)"></div>

              <!-- Tool Calls -->
              <div v-if="msg.tools && msg.tools.length" class="space-y-2 mt-2">
                <div
                  v-for="(t, tidx) in msg.tools"
                  :key="tidx"
                  class="rounded bg-zinc-950 p-2.5 border border-zinc-800 text-xs font-mono space-y-1"
                >
                  <div class="text-amber-400 font-semibold flex items-center space-x-1.5">
                    <span>⚙ Tool:</span>
                    <span>{{ t.name }}</span>
                  </div>
                  <pre class="text-zinc-400 text-[11px] overflow-x-auto p-1 bg-zinc-900/50 rounded">{{ t.params }}</pre>
                  <div v-if="t.result" class="text-emerald-400 text-[11px] mt-1 border-t border-zinc-800/60 pt-1">
                    ✓ Result: {{ t.result }}
                  </div>
                </div>
              </div>

              <!-- Tool Permission Request Approval Banner -->
              <div v-if="msg.permissionRequest" class="mt-3 p-3 bg-amber-950/40 border border-amber-600/60 rounded-lg">
                <div class="text-xs text-amber-300 font-semibold mb-1 flex items-center space-x-1.5">
                  <span>⚠ Tool Permission Requested</span>
                </div>
                <div class="text-xs text-zinc-300 mb-2 font-mono bg-zinc-950/80 p-2 rounded">
                  {{ msg.permissionRequest.title || JSON.stringify(msg.permissionRequest) }}
                </div>
                <div class="flex space-x-2">
                  <button
                    @click="resolvePermission(msg.permissionRequest.id, true)"
                    class="px-3 py-1 bg-emerald-600 hover:bg-emerald-500 text-white rounded text-xs font-medium transition"
                  >
                    Allow
                  </button>
                  <button
                    @click="resolvePermission(msg.permissionRequest.id, false)"
                    class="px-3 py-1 bg-rose-600 hover:bg-rose-500 text-white rounded text-xs font-medium transition"
                  >
                    Deny
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>

        <!-- Input Bar -->
        <footer class="p-3 border-t border-zinc-800 bg-zinc-900/40">
          <form @submit.prevent="sendMessage" class="flex flex-col space-y-2">
            <textarea
              v-model="promptInput"
              @keydown.enter.exact.prevent="sendMessage"
              placeholder="Type your instruction to omp (Enter to send, Shift+Enter for newline)..."
              rows="3"
              class="w-full bg-zinc-900 border border-zinc-800 focus:border-amber-500 rounded-lg p-2.5 text-sm text-zinc-100 placeholder-zinc-500 focus:outline-none resize-none font-sans"
            ></textarea>
            <div class="flex justify-between items-center">
              <span class="text-[11px] text-zinc-500">Press Enter to send</span>
              <button
                type="submit"
                :disabled="!promptInput.trim() || !isConnected"
                class="px-4 py-1.5 bg-amber-600 hover:bg-amber-500 disabled:opacity-50 disabled:pointer-events-none text-white rounded-md text-xs font-medium transition"
              >
                Send
              </button>
            </div>
          </form>
        </footer>
      </template>

      <!-- Empty State -->
      <div v-else class="flex-1 flex flex-col items-center justify-center text-zinc-500 space-y-3">
        <span class="text-4xl text-zinc-700">⌥</span>
        <p class="text-sm">Select a session from the sidebar or create a new one.</p>
        <button
          @click="showNewModal = true"
          class="px-4 py-2 bg-amber-600 hover:bg-amber-500 text-white rounded-lg text-xs font-medium transition"
        >
          Create Session
        </button>
      </div>
    </main>

    <!-- New Session Modal -->
    <div v-if="showNewModal" class="fixed inset-0 bg-black/70 flex items-center justify-center p-4 z-50">
      <div class="bg-zinc-900 border border-zinc-800 rounded-xl w-full max-w-md p-5 shadow-2xl space-y-4">
        <h3 class="text-sm font-semibold text-zinc-100">Create New Session</h3>
        <div class="space-y-1.5">
          <label class="text-xs text-zinc-400">Working Directory (CWD):</label>
          <input
            v-model="newCwdInput"
            type="text"
            placeholder="/home/chn/repo/nixos"
            class="w-full bg-zinc-950 border border-zinc-800 focus:border-amber-500 rounded-lg px-3 py-2 text-xs font-mono text-zinc-100 focus:outline-none"
          />
          <p class="text-[11px] text-zinc-500">The session will be spawned in this directory with full local context.</p>
        </div>
        <div class="flex justify-end space-x-2 pt-2">
          <button
            @click="showNewModal = false"
            class="px-3 py-1.5 text-xs text-zinc-400 hover:text-zinc-200 hover:bg-zinc-800 rounded transition"
          >
            Cancel
          </button>
          <button
            @click="submitNewSession"
            :disabled="creating"
            class="px-4 py-1.5 text-xs bg-amber-600 hover:bg-amber-500 text-white rounded font-medium transition disabled:opacity-50"
          >
            {{ creating ? 'Spawning...' : 'Create' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted, nextTick, watch } from 'vue';
import { marked } from 'marked';

const sessions = ref([]);
const activeSessionId = ref(null);
const activeSession = ref(null);
const messages = ref([]);
const promptInput = ref('');
const showNewModal = ref(false);
const newCwdInput = ref('/home/chn/repo/nixos');
const creating = ref(false);
const isConnected = ref(false);
const chatContainer = ref(null);

let ws = null;
let currentMessage = null;

function getDirName(path) {
  if (!path) return 'Workspace';
  const parts = path.split('/').filter(Boolean);
  return parts.length ? parts[parts.length - 1] : path;
}

function renderMarkdown(content) {
  try {
    return marked.parse(content || '');
  } catch {
    return content;
  }
}

async function fetchSessions() {
  try {
    const res = await fetch('/api/sessions');
    if (res.ok) {
      sessions.value = await res.json();
      if (!activeSessionId.value && sessions.value.length > 0) {
        selectSession(sessions.value[0].id);
      }
    }
  } catch (err) {
    console.error('Failed to fetch sessions:', err);
  }
}

function selectSession(id) {
  if (activeSessionId.value === id) return;
  activeSessionId.value = id;
  activeSession.value = sessions.value.find((s) => s.id === id) || null;
  messages.value = [];
  connectWebSocket(id);
}

function connectWebSocket(id) {
  if (ws) {
    ws.close();
    ws = null;
  }
  isConnected.value = false;

  const protocol = window.location.protocol === 'https:' ? 'wss:' : 'ws:';
  const wsUrl = `${protocol}//${window.location.host}/api/sessions/${id}/ws`;

  ws = new WebSocket(wsUrl);

  ws.onopen = () => {
    isConnected.value = true;
  };

  ws.onclose = () => {
    isConnected.value = false;
  };

  ws.onerror = (e) => {
    console.error('WS Error:', e);
    isConnected.value = false;
  };

  ws.onmessage = (event) => {
    try {
      const data = JSON.parse(event.data);
      handleAcpMessage(data);
    } catch {
      // Plain text output
      appendAssistantChunk(event.data);
    }
  };
}

function handleAcpMessage(msg) {
  // ACP JSON-RPC message dispatching
  if (msg.method === 'session/update' || msg.method === 'notifications/message') {
    const params = msg.params || {};
    if (params.thinking) {
      ensureCurrentMessage();
      currentMessage.thinking = (currentMessage.thinking || '') + params.thinking;
    }
    if (params.delta || params.text) {
      appendAssistantChunk(params.delta || params.text);
    }
    if (params.tool) {
      ensureCurrentMessage();
      currentMessage.tools = currentMessage.tools || [];
      currentMessage.tools.push(params.tool);
    }
  } else if (msg.method === 'request_permission' || msg.method === 'session/request_permission') {
    ensureCurrentMessage();
    currentMessage.permissionRequest = {
      id: msg.id,
      title: msg.params?.title || msg.params?.command || JSON.stringify(msg.params),
    };
  } else if (msg.result && currentMessage) {
    if (msg.result.text) {
      currentMessage.text = (currentMessage.text || '') + msg.result.text;
    }
  }
  scrollToBottom();
}

function ensureCurrentMessage() {
  if (!currentMessage || currentMessage.role !== 'assistant') {
    currentMessage = {
      role: 'assistant',
      text: '',
      thinking: '',
      tools: [],
      permissionRequest: null,
    };
    messages.value.push(currentMessage);
  }
}

function appendAssistantChunk(chunk) {
  ensureCurrentMessage();
  currentMessage.text += chunk;
  scrollToBottom();
}

function scrollToBottom() {
  nextTick(() => {
    if (chatContainer.value) {
      chatContainer.value.scrollTop = chatContainer.value.scrollHeight;
    }
  });
}

function sendMessage() {
  const text = promptInput.value.trim();
  if (!text || !ws || !isConnected.value) return;

  messages.value.push({
    role: 'user',
    text,
  });

  // ACP session/prompt format
  const rpc = {
    jsonrpc: '2.0',
    id: Date.now(),
    method: 'session/prompt',
    params: {
      prompt: [{ type: 'text', text }],
    },
  };

  ws.send(JSON.stringify(rpc));
  promptInput.value = '';
  currentMessage = null;
  scrollToBottom();
}

function resolvePermission(requestId, approved) {
  if (!ws || !isConnected.value) return;
  const resp = {
    jsonrpc: '2.0',
    id: requestId,
    result: { approved },
  };
  ws.send(JSON.stringify(resp));
  if (currentMessage) {
    currentMessage.permissionRequest = null;
  }
}

async function closeSession(id) {
  try {
    await fetch(`/api/sessions/${id}`, { method: 'DELETE' });
    sessions.value = sessions.value.filter((s) => s.id !== id);
    if (activeSessionId.value === id) {
      activeSessionId.value = null;
      activeSession.value = null;
      if (sessions.value.length > 0) {
        selectSession(sessions.value[0].id);
      }
    }
  } catch (err) {
    console.error('Failed to close session:', err);
  }
}

async function submitNewSession() {
  creating.value = true;
  try {
    const res = await fetch('/api/sessions', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ cwd: newCwdInput.value.trim() }),
    });
    if (res.ok) {
      const created = await res.json();
      sessions.value.unshift(created);
      selectSession(created.id);
      showNewModal.value = false;
    } else {
      const err = await res.text();
      alert(`Error spawning session: ${err}`);
    }
  } catch (err) {
    alert(`Failed to create session: ${err}`);
  } finally {
    creating.value = false;
  }
}

onMounted(() => {
  fetchSessions();
});
</script>
