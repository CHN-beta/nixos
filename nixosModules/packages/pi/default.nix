{
  lib,
  config,
  self,
  pkgs,
  ...
}:
let
  hindsight = import ./hindsight.nix { inherit pkgs; };

  imageModel = id: name: {
    inherit id name;
    input = [
      "text"
      "image"
    ];
    contextWindow = 400000;
    maxTokens = 128000;
  };

  providers = {
    cliproxyapi = {
      baseUrl = "https://cliproxyapi.chn.moe/v1";
      api = "openai-completions";
      apiKey = "$CLIPROXYAPI_API_KEY";
      models = [
        (imageModel "gpt-5.6-sol" "GPT-5.6 Sol")
        (imageModel "gpt-5.6-terra" "GPT-5.6 Terra")
        (imageModel "gpt-5.6-luna" "GPT-5.6 Luna")
        (imageModel "gpt-6-astra" "GPT-6 Astra")
        (imageModel "gemini-3.1-pro-low" "Gemini 3.1 Pro Low")
        (imageModel "gemini-3.8-flash-high" "Gemini 3.8 Flash High")
        (imageModel "claude-sonnet-5" "Claude Sonnet 5")
        (imageModel "claude-opus-5" "Claude Opus 5")
        (imageModel "claude-fable-5" "Claude Fable 5")
        (imageModel "claude-fable-5-1" "Claude Fable 5.1")
      ];
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
    deepseek = {
      baseUrl = "https://api.deepseek.com";
      api = "openai-completions";
      apiKey = "$DEEPSEEK_API_KEY";
      models = [
        {
          id = "deepseek-flash";
          name = "DeepSeek-V4.1 Flash";
          input = [
            "text"
            "image"
          ];
          contextWindow = 1000000;
          maxTokens = 384000;
        }
        {
          id = "deepseek-v4-pro";
          name = "DeepSeek-V4 Pro";
          input = [ "text" ];
          contextWindow = 1000000;
          maxTokens = 384000;
        }
      ];
    };
  };

  mcpServers = {
    dockerhub.command = lib.getExe pkgs.localPkgs.dockerhub-mcp;
    openalex.command = lib.getExe pkgs.python3Packages.alex-mcp;
    mineru.command = lib.getExe pkgs.python3Packages.mineru-mcp;
    nixos.command = lib.getExe pkgs.mcp-nixos;
    qdrant = {
      command = lib.getExe pkgs.localPkgs.mcp-server-qdrant;
      requestTimeoutMs = 300000;
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
    vikunja = {
      command = lib.getExe pkgs.localPkgs.vikunja-mcp;
      env.VIKUNJA_URL = "https://vikunja.chn.moe";
    };
    github = {
      url = "https://api.githubcopilot.com/mcp/";
      auth = "bearer";
      bearerTokenEnv = "GITHUB_TOKEN";
    };
    agent-browser = {
      command = lib.getExe self.inputs.llm-agents.packages.x86_64-linux.agent-browser;
      args = [
        "mcp"
        "--tools"
        "core,tabs"
      ];
    };
  };

  environment = {
    HINDSIGHT_API_TOKEN.file = config.nixos.system.sops.secrets."straycat/hindsight".path;
    HINDSIGHT_API_URL.value = "https://hindsight.chn.moe";
    HINDSIGHT_BANK_ID.value = "chn";
    HINDSIGHT_CONFIG.value = "${hindsight.configFile}";
    OPENALEX_MAILTO.value = "chn@chn.moe";
    MINERU_API_KEY.file = config.nixos.system.sops.secrets."straycat/mineru".path;
    CLIPROXYAPI_API_KEY.file = config.nixos.system.sops.secrets."straycat/cliproxyapi".path;
    QDRANT_API_KEY.file = config.nixos.system.sops.secrets."straycat/qdrant".path;
    OPENAI_API_KEY.file = config.nixos.system.sops.secrets."straycat/siliconflow".path;
    DEEPSEEK_API_KEY.file = config.nixos.system.sops.secrets."straycat/deepseek".path;
    GITHUB_TOKEN.file = config.nixos.system.sops.secrets."straycat/github".path;
    VIKUNJA_API_TOKEN.file = config.nixos.system.sops.secrets."straycat/vikunja".path;
    PI_SKIP_VERSION_CHECK.value = "1";
  };
in
{
  options.nixos.packages.pi = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule { });
    default = null;
  };
  config = lib.mkIf (config.nixos.packages.pi != null) {
    environment.persistence."/nix/persistent".users.chn.directories = [
      ".pi/agent/sessions"
      ".pi/agent/npm"
    ];
    nixos.user.sharedModules = [
      {
        config = {
          home = {
            packages = [
              (pkgs.texlive.combine {
                inherit (pkgs.texlive) scheme-small dvipng preview;
              })
              # needed by the agent-browser MCP server
              self.inputs.llm-agents.packages.x86_64-linux.agent-browser
            ];
            file = {
              ".pi/agent/models.json".text = builtins.toJSON { inherit providers; };
              ".pi/agent/keybindings.json".text = builtins.toJSON {
                "tui.input.newLine" = [ "enter" ];
                "tui.input.submit" = [ "ctrl+enter" ];
              };
              # pi-permissions ignores individual symlinked files but loads a
              # symlinked directory whose entries are regular files.
              ".pi/agent/permissions".source = ./extensions/permissions;
            };
          };
          xdg.configFile."mcp/mcp.json".text = builtins.toJSON {
            inherit mcpServers;
            settings = {
              mcpFooterStatus = "compact";
              toolPrefix = "server";
            };
          };
          programs.pi.coding-agent = {
            enable = true;
            rules = ./instructions.md;
            extensions = [ hindsight.extension ];
            skills = [ hindsight.skill ];
            themes = [ "${self.inputs.pi-catppuccin}/catppuccin-latte.json" ];
            inherit environment;
            settings = {
              theme = "catppuccin-latte";
              defaultProvider = "cliproxyapi";
              defaultModel = "gemini-3.8-flash-high";
              enableInstallTelemetry = false;
              hideThinkingBlock = true;
              defaultThinkingLevel = "high";
              tuiMode = "fullscreen";
              packages = [
                "npm:pi-mcp-adapter@2.34.0"
                "npm:pi-subagents@0.68.0"
                "npm:@thurstonsand/pi-permissions@0.11.0"
                "npm:pi-notify@1.4.0"
                "npm:@monotykamary/pi-math@0.5.4"
                "npm:pi-markdown-preview@0.17.0"
                "npm:@narumitw/pi-plan-mode@0.58.0"
                "npm:@juicesharp/rpiv-todo@2.10.1"
                "npm:@juicesharp/rpiv-ask-user-question@2.10.1"
              ];
            };
          };
        };
      }
    ];
  };
}
