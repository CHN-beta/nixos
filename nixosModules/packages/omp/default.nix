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
          };
    }
    |> builtins.toJSON
    |> pkgs.writeText "omp-mcp.json";

  keybindingsFile =
    user:
    {
      "tui.input.newLine" = [ "enter" ];
      "tui.input.submit" = [ "ctrl+enter" ];
    }
    |> lib.optionalAttrs (user != "wyh")
    |> builtins.toJSON
    |> pkgs.writeText "omp-keybindings.yml";

  agents = {
    doc = {
      description = "文档撰写、资料检索、技术报告与文书整理";
      model = "cliproxyapi/gemini-3.8-flash-high";
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
      description = "核心代码实现、逻辑重构、故障排查与测试验证";
      model = "cliproxyapi/deepseek-flash";
      prompt = ''
        你是一个精通系统设计与工程实现的代码专家。
        职责：
        1. 深入理解项目架构与既有惯例，高质量实现核心业务逻辑。
        2. 进行精确的代码重构、排查定位 Bug 并完成修复。
        3. 编写与完善单元测试及集成测试，利用 bash、lsp 工具验证代码正确性。
        注重代码质量、健壮性与性能，严格遵循项目现有规范。
      '';
    };
    math = {
      description = "形式化理论推导、数学物理计算、量纲分析与数值验证";
      model = "cliproxyapi/gemini-3.8-flash-high";
      prompt = ''
        你是一个理论物理与应用数学专家。
        职责：
        1. 进行形式化数学与物理理论推导，建立清晰、分步的物理逻辑链条，优先以物理直觉与图像锚定数学结构。
        2. 进行严格的量纲分析、对称性检验、边界渐近行为分析及数值验证。
        3. 输出数学公式时直接提供规范的 LaTeX 源码，便于复制与检验。
        4. 必要时利用 eval（Python / NumPy / SymPy）或 bash 脚本进行精确的数值检验与符号推导。
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

  settings = user: {
    modelRoles.default = "cliproxyapi/gemini-3.8-flash-high";
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
              run mkdir -p "$HOME/.omp/agent/agents"
              run rm -f "$HOME/.omp/agent/models.yml" "$HOME/.omp/agent/mcp.json" "$HOME/.omp/agent/keybindings.yml"
              run install -m 600 ${modelsFile} "$HOME/.omp/agent/models.yml"
              run install -m 600 ${mcpFile homeInputs.config.home.username} "$HOME/.omp/agent/mcp.json"
              run install -m 600 ${keybindingsFile homeInputs.config.home.username} "$HOME/.omp/agent/keybindings.yml"
              ${lib.concatLines (
                lib.mapAttrsToList (
                  name: file: ''
                    run rm -f "$HOME/.omp/agent/agents/${name}.md"
                    run install -m 600 ${file} "$HOME/.omp/agent/agents/${name}.md"
                  ''
                ) agentFiles
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
