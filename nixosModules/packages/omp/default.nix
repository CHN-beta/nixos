{
  lib,
  config,
  pkgs,
  ...
}:
let
  modelsFile =
    {
      providers = {
        cliproxyapi = {
          baseUrl = "https://cliproxyapi.chn.moe/v1";
          api = "openai-completions";
          apiKey = "CLIPROXYAPI_API_KEY";
          discovery.type = "openai-models-list";
        };
        ollama = {
          baseUrl = "https://ollama.chn.moe/v1";
          api = "openai-completions";
          apiKey = "ollama";
          models = [
            {
              id = "hf.co/unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M";
              name = "Qwen3.8 27B (UD-Q4_K_M)";
              input = [
                "text"
                "image"
              ];
              contextWindow = 262144;
              maxTokens = 131072;
            }
          ];
        };
        doubao = {
          baseUrl = "https://ark.cn-beijing.volces.com/api/v3";
          api = "openai-responses";
          apiKey = "ARK_API_KEY";
          models = [
            {
              id = "doubao-seed-evolving";
              name = "Doubao Seed Evolving";
              input = [
                "text"
                "image"
              ];
              contextWindow = 1048576;
              maxTokens = 262144;
            }
          ];
        };
      };
    }
    |> builtins.toJSON
    |> pkgs.writeText "omp-models.yml";

  mcpFile =
    user:
    {
      mcpServers = {
        dockerhub.command = lib.getExe pkgs.localPkgs.dockerhub-mcp;
        openalex.command = lib.getExe pkgs.python3Packages.alex-mcp;
        mineru.command = lib.getExe pkgs.python3Packages.mineru-mcp;
        nixos.command = lib.getExe pkgs.mcp-nixos;
        qdrant = {
          command = lib.getExe pkgs.localPkgs.mcp-server-qdrant;
          timeout = 300000;
          env = {
            QDRANT_URL = "https://qdrant.chn.moe:443";
            EMBEDDING_PROVIDER = "bge-m3";
            EMBEDDING_MODEL = "BAAI/bge-m3";
            BGE_M3_BASE_URL = "https://bgem3.chn.moe";
            TOOL_STORE_DESCRIPTION = "Store information in a specified Qdrant collection for semantic retrieval. Use this only when the user explicitly asks to use Qdrant; otherwise use Hindsight for memory.";
            TOOL_FIND_DESCRIPTION = "Search a specified Qdrant collection by meaning and return relevant information with metadata. Use this only when the user explicitly asks to use Qdrant; otherwise use Hindsight for memory retrieval.";
          };
        };
        translate = {
          command = lib.getExe pkgs.localPkgs.translate-mcp;
          args = [
            "-transport"
            "stdio"
            "-config"
            "${./translate-mcp.yaml}"
          ];
        };
      }
      //
        lib.optionalAttrs
          (lib.elem user [
            "chn"
            "straycat"
          ])
          {
            vikunja = {
              command = lib.getExe pkgs.localPkgs.vikunja-mcp;
              env.VIKUNJA_URL = "https://vikunja.chn.moe";
            };
            matrix = {
              command = lib.getExe pkgs.localPkgs.matrix-mcp;
              env = {
                MATRIX_HOMESERVER = "https://matrix.chn.moe";
                MATRIX_USER = "hermes";
              };
            };
          };
    }
    |> builtins.toJSON
    |> pkgs.writeText "omp-mcp.json";

  keybindingsFile =
    user:
    {
      "tui.input.newLine" = [ "enter" ];
      "tui.input.submit" = [ "ctrl+shift+enter" ];
      "app.message.followUp" = [ "ctrl+enter" ];
    }
    |> lib.optionalAttrs (
      lib.elem user [
        "chn"
        "straycat"
      ]
    )
    |> builtins.toJSON
    |> pkgs.writeText "omp-keybindings.yml";

  agents = {
    doc = {
      description = "文档撰写、资料检索、技术报告与文书整理";
      model = "cliproxyapi/gemini-3.8-flash";
      prompt = ''
        你是一个技术文书、资料检索与系统设计说明专家。
        职责：
        1. 编写清晰、详尽、结构良好的工程与系统文档、API 说明、README、技术报告与调研纪要。
        2. 检索并整合外部技术资料、开源项目实现及相关背景知识。
        3. 协助梳理需求规格，草拟面向用户或团队的交流文书。
        要求语言严谨专业、格式规整清晰，逻辑层次分明。
      '';
    };
    code = {
      description = "核心业务代码实现、常规重构、单元测试与构建验证";
      model = "cliproxyapi/deepseek-flash";
      prompt = ''
        你是一个精通工程实现与测试验证的代码开发专家。
        职责：
        1. 深入理解项目架构、接口契约与既有惯例，高质量、高效率地实现核心业务逻辑。
        2. 执行结构清晰的代码重构、模块组装与样板代码实现。
        3. 编写与完善单元测试及集成测试，利用 bash、lsp 工具验证构建与测试通过。
        注重代码可读性、健壮性与性能，严格遵循项目现有规范。
      '';
    };
    debug = {
      description = "疑难故障排查、Bug 根因定位、并发/崩溃诊断与代码安全审查";
      model = "cliproxyapi/gemini-4-argon";
      prompt = ''
        你是一个精通复杂系统故障诊断、根因分析与代码审查的排障专家。
        职责：
        1. 针对疑难 Bug、测试失败、崩溃、死锁、竞态条件与性能退化进行基于证据的根因定位（Root-Cause Analysis）。
        2. 严禁凭空猜测 API 或掩盖报错表象；优先通过日志、堆栈、源码追踪、最小复现脚本与 lsp 精确锁定问题源头。
        3. 进行严密的代码边界条件、状态不变量与安全性审查，实施最小化、可验证的精确修复并确认回归测试通过。
      '';
    };
    design = {
      description = "系统架构设计、模块接口契约、代码迁移方案与前端交互设计";
      model = "cliproxyapi/gemini-4-argon";
      prompt = ''
        你是一个精通系统架构与前端交互的架构及设计专家。
        职责：
        1. 制定清晰的系统架构方案、模块职责边界、数据结构与 API 接口契约，拒绝过度设计与冗余抽象。
        2. 规划跨模块重构、技术栈迁移蓝图与分阶段演进路线，确保接口兼容性与可维护性。
        3. 设计直观、美观、响应式的前端 UI/UX 组件结构、状态流转与交互细节。
      '';
    };
    math = {
      description = "形式化理论推导、数学物理计算、量纲分析与数值验证";
      model = "cliproxyapi/gemini-4-argon";
      prompt = ''
        你是一个理论物理与应用数学专家。
        职责：
        1. 进行形式化数学与物理理论推导，建立清晰、分步的物理逻辑链条，优先以物理直觉与图像锚定数学结构。
        2. 进行严格的量纲分析、对称性检验、边界渐近行为分析及数值验证。
        3. 输出数学公式时直接提供规范的 LaTeX 源码，便于复制与检验。
        4. 必要时利用 eval（Python / NumPy / SymPy）或 bash 脚本进行精确的数值检验与符号推导。
      '';
    };
    exec = {
      description = "执行明确指令与机械性操作（如检查 Git 状态与提交、文件批处理、运行指定命令等）";
      model = "cliproxyapi/deepseek-flash";
      prompt = ''
        你是一个精准、高效的机械性操作执行专家。
        职责：
        1. 严格按照用户的明确指令执行操作：检查 git status / git diff 并提交、运行指定命令、批量文件处理与清晰的常规运维操作。
        2. 拒绝过度设计与范围蔓延，只完成被要求的操作，不擅自扩展任务、重构代码或添加额外改动。
        3. 汇报简洁准确：说明实际执行的命令、产生的结果与关键输出摘要；失败时立即如实报告原因。
        追求准确、迅速、简洁，不夸大也不隐瞒执行结果。
      '';
    };
  };

  agentFiles = lib.mapAttrs (
    name: agent:
    pkgs.writeText "omp-agent-${name}.md" ''
      ---
      name: ${name}
      description: ${agent.description}
      model: ${agent.model}
      ${lib.optionalString (agent ? tools) "tools: ${lib.concatStringsSep ", " agent.tools}\n"}---
      ${agent.prompt}
    ''
  ) agents;

  vibePromptExtension = pkgs.writeText "omp-vibe-prompt.ts" ''
    import type { ExtensionAPI } from "@oh-my-pi/pi-coding-agent";

    const VIBE_DIRECTOR_INSTRUCTIONS = `<vibe-user-preferences>
    Vibe 模式调度准则：
    1. 积极派发：除非是非常简单的任务（例如仅用 \`read\` 读取单个文件即可直接回答），否则必须将任务拆解并通过 \`vibe_spawn\` / \`vibe_send\` 派发给对应领域的 subagent（\`doc\` / \`code\` / \`debug\` / \`design\` / \`math\` / \`exec\`）执行。
    2. 非阻塞立即回复：调用 \`vibe_spawn\` 或 \`vibe_send\` 派发任务后，立即结束当前回合并直接回复用户（扼要告知已派发的 worker 及任务安排），让用户可以继续输入新指令。仅在用户明确要求等待结果时才调用 \`vibe_wait\`。
    3. 完成后汇报总结：当后台 subagent 执行完毕、异步结果投递回主会话触发新一轮响应时，先核实结果（必要时 \`read\` 检查修改的文件），再向用户输出清晰、精炼的完成情况总结。
    </vibe-user-preferences>`;

    export default function (pi: ExtensionAPI) {
      pi.on("before_agent_start", async (_event, ctx) => {
        if (ctx.agent.kind !== "main") return;
        if (!pi.getActiveTools().includes("vibe_spawn")) return;
        return {
          message: {
            customType: "vibe-mode-context",
            content: VIBE_DIRECTOR_INSTRUCTIONS,
            display: false,
            attribution: "agent",
          },
        };
      });
    }
  '';

  settings = user: {
    modelRoles.default = "cliproxyapi/gemini-4-argon:medium";
    defaultThinkingLevel = "high";
    hideThinkingBlock = true;
    symbolPreset = "nerd";
    theme = {
      dark = "dark-catppuccin";
      light = "light-catppuccin";
    };
    startup.checkUpdate = false;
    telemetry.otlpExportEnabled = false;
    memory.backend = "hindsight";
    hindsight = {
      apiUrl = "https://hindsight.chn.moe";
      bankId = { straycat = "chn"; }.${user} or user;
      scoping = "global";
    };
    github.enabled = true;
    setupVersion = 2;
  };
in
{
  options.nixos.packages.omp = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule { });
    default = null;
  };
  config = lib.mkIf (config.nixos.packages.omp != null) {
    environment.persistence."/nix/persistent".users.chn.directories = [ ".omp" ];
    nixos.user.sharedModules = [
      (homeInputs: {
        config = {
          home.activation.ompAgentConfig = {
            before = [ ];
            after = [ "writeBoundary" ];
            data = ''
              run mkdir -p "$HOME/.omp/agent/agents" "$HOME/.omp/agent/extensions"
              run rm -f "$HOME/.omp/agent/models.yml" "$HOME/.omp/agent/mcp.json" "$HOME/.omp/agent/keybindings.yml" "$HOME/.omp/agent/extensions/vibe-prompt.ts"
              run install -m 600 ${modelsFile} "$HOME/.omp/agent/models.yml"
              run install -m 600 ${mcpFile homeInputs.config.home.username} "$HOME/.omp/agent/mcp.json"
              run install -m 600 ${keybindingsFile homeInputs.config.home.username} "$HOME/.omp/agent/keybindings.yml"
              run install -m 600 ${vibePromptExtension} "$HOME/.omp/agent/extensions/vibe-prompt.ts"
              ${lib.concatLines (
                lib.mapAttrsToList (name: file: ''
                  run rm -f "$HOME/.omp/agent/agents/${name}.md"
                  run install -m 600 ${file} "$HOME/.omp/agent/agents/${name}.md"
                '') agentFiles
              )}
            '';
          };
          programs.omp = {
            enable = true;
            settings = settings homeInputs.config.home.username;
            package = pkgs.writeShellScriptBin "omp" ''
              export HINDSIGHT_API_TOKEN="$(cat "${config.nixos.system.sops.secrets."straycat/hindsight".path}")"
              export MINERU_API_KEY="$(cat "${config.nixos.system.sops.secrets."straycat/mineru".path}")"
              export CLIPROXYAPI_API_KEY="$(cat "${
                config.nixos.system.sops.secrets."straycat/cliproxyapi".path
              }")"
              export QDRANT_API_KEY="$(cat "${config.nixos.system.sops.secrets."straycat/qdrant".path}")"
              export OPENAI_API_KEY="$(cat "${config.nixos.system.sops.secrets."straycat/siliconflow".path}")"
              export GITHUB_TOKEN="$(cat "${config.nixos.system.sops.secrets."straycat/github".path}")"
              export ARK_API_KEY="$(cat "${config.nixos.system.sops.secrets."straycat/ark".path}")"
              export MATRIX_PASSWORD="$(cat "${config.nixos.system.sops.secrets."straycat/matrix".path}")"
              ${
                if
                  lib.elem homeInputs.config.home.username [
                    "chn"
                    "straycat"
                  ]
                then
                  ''export VIKUNJA_API_TOKEN="$(cat "${config.nixos.system.sops.secrets."straycat/vikunja".path}")"''
                else
                  ""
              } 
              export OPENALEX_MAILTO=chn@chn.moe

              export PUPPETEER_EXECUTABLE_PATH=${pkgs.chromium}/bin/chromium

              exec ${lib.getExe pkgs.omp} "$@"
            '';
          };
        };
      })
    ];
  };
}
