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
          models =
            [
              {
                id = "gpt-6-astra";
                name = "GPT-6 Astra";
              }
              {
                id = "gpt-6-luna";
                name = "GPT-6 Luna";
              }
              {
                id = "gemini-3.1-pro-low";
                name = "Gemini 3.1 Pro Low";
              }
              {
                id = "gemini-3.8-flash-high";
                name = "Gemini 3.8 Flash High";
              }
            ]
            |> map (
              attr:
              attr
              // {
                input = [
                  "text"
                  "image"
                ];
                contextWindow = 400000;
                maxTokens = 128000;
              }
            );
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
          apiKey = "DEEPSEEK_API_KEY";
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
    }
    |> builtins.toJSON
    |> pkgs.writeText "omp-models.yml";

  mcpFile =
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
        vikunja = {
          command = lib.getExe pkgs.localPkgs.vikunja-mcp;
          env.VIKUNJA_URL = "https://vikunja.chn.moe";
        };
      };
    }
    |> builtins.toJSON
    |> pkgs.writeText "omp-mcp.json";

  keybindingsFile =
    {
      "tui.input.newLine" = [ "enter" ];
      "tui.input.submit" = [ "ctrl+enter" ];
    }
    |> builtins.toJSON
    |> pkgs.writeText "omp-keybindings.yml";

  settings = {
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
    # pi's confirm-operations permission handler prompts for everything that is
    # not a read-only tool, which is what `always-ask` means here.
    tools.approvalMode = "always-ask";
    memory.backend = "hindsight";
    hindsight = {
      apiUrl = "https://hindsight.chn.moe";
      bankId = "chn";
      scoping = "global";
    };
    github.enabled = true;
    tui.mouse = true;
  };
in
{
  options.nixos.packages.omp = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule { });
    default = null;
  };
  config = lib.mkIf (config.nixos.packages.omp != null) {
    environment.persistence."/nix/persistent".users.chn.directories = [
      ".omp/agent/sessions"
      ".omp/agent/blobs"
      ".omp/plugins"
    ];
    nixos.user.sharedModules = [
      {
        config = {
          home.activation.ompAgentConfig = {
            before = [ ];
            after = [ "writeBoundary" ];
            data = ''
              run mkdir -p "$HOME/.omp/agent"
              run rm -f "$HOME/.omp/agent/models.yml" "$HOME/.omp/agent/mcp.json" "$HOME/.omp/agent/keybindings.yml"
              run install -m 600 ${modelsFile} "$HOME/.omp/agent/models.yml"
              run install -m 600 ${mcpFile} "$HOME/.omp/agent/mcp.json"
              run install -m 600 ${keybindingsFile} "$HOME/.omp/agent/keybindings.yml"
            '';
          };
          programs.omp = {
            enable = true;
            inherit settings;
            package = pkgs.writeShellScriptBin "omp" ''
              export HINDSIGHT_API_TOKEN="$(cat "${config.nixos.system.sops.secrets."straycat/hindsight".path}")"
              export MINERU_API_KEY="$(cat "${config.nixos.system.sops.secrets."straycat/mineru".path}")"
              export CLIPROXYAPI_API_KEY="$(cat "${
                config.nixos.system.sops.secrets."straycat/cliproxyapi".path
              }")"
              export QDRANT_API_KEY="$(cat "${config.nixos.system.sops.secrets."straycat/qdrant".path}")"
              export OPENAI_API_KEY="$(cat "${config.nixos.system.sops.secrets."straycat/siliconflow".path}")"
              export DEEPSEEK_API_KEY="$(cat "${config.nixos.system.sops.secrets."straycat/deepseek".path}")"
              export GITHUB_TOKEN="$(cat "${config.nixos.system.sops.secrets."straycat/github".path}")"
              export VIKUNJA_API_TOKEN="$(cat "${config.nixos.system.sops.secrets."straycat/vikunja".path}")"
              export OPENALEX_MAILTO=chn@chn.moe

              export PUPPETEER_EXECUTABLE_PATH=${pkgs.chromium}/bin/chromium

              exec ${lib.getExe pkgs.omp} "$@"
            '';
          };
        };
      }
    ];
  };
}
