{
  lib,
  config,
  self,
  pkgs,
  ...
}:
{
  options.nixos.packages.opencode = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule { });
    default = null;
  };
  config = lib.mkIf (config.nixos.packages.opencode != null) (
    let
      opencode-wrapped = pkgs.writeShellScriptBin "opencode" ''
        export HINDSIGHT_API_TOKEN=$(cat ${config.nixos.system.sops.secrets."opencode/hindsight".path})
        export HINDSIGHT_API_URL=https://hindsight.chn.moe
        export HINDSIGHT_BANK_ID=chn
        export OPENALEX_MAILTO=chn@chn.moe
        export MINERU_API_KEY=$(cat ${config.nixos.system.sops.secrets."opencode/mineru".path})
        export CLIPROXYAPI_API_KEY=$(cat ${config.nixos.system.sops.secrets."opencode/cliproxyapi".path})
        exec ${lib.getExe self.inputs.llm-agents.packages.x86_64-linux.opencode} "$@"
      '';
    in
    {
      environment.persistence."/nix/persistent".users.chn.directories = [ ".cache/opencode" ];
      nixos.system.sops.secrets = {
        "opencode/github" = {
          owner = "chn";
          key = "github/token";
        };
        "github/token" = { };
        "opencode/cliproxyapi".owner = "chn";
        "opencode/mineru".owner = "chn";
        "opencode/hindsight" = {
          owner = "chn";
          key = "hindsight/password";
        };
        "hindsight/password" = { };
      };
      home-manager.users.chn.config = {
        home.packages = [
          opencode-wrapped
          # needed by opencode-notifier
          pkgs.libnotify
          self.inputs.llm-agents.packages.x86_64-linux.agent-browser
        ];
        programs.opencode = {
          enable = true;
          package = opencode-wrapped;
          enableMcpIntegration = true;
          tui.keybinds = {
            input_submit = "ctrl+return";
            input_newline = "return";
          };
          settings = {
            instructions = [
              "${./instructions.md}"
            ];
            model = "gpt-5.6-terra";
            small_model = "gpt-5.6-terra";
            provider = {
              cliproxyapi = {
                options = {
                  baseURL = "https://cliproxyapi.chn.moe/v1";
                  apiKey = "{file:${config.nixos.system.sops.secrets."opencode/cliproxyapi".path}}";
                };
                models = {
                  "gpt-5.6-sol" = {
                    name = "GPT-5.6 Sol";
                    limit = {
                      context = 400000;
                      output = 128000;
                    };
                    modalities = {
                      input = [
                        "text"
                        "image"
                      ];
                      output = [ "text" ];
                    };
                  };
                  "gpt-5.6-terra" = {
                    name = "GPT-5.6 Terra";
                    limit = {
                      context = 400000;
                      output = 128000;
                    };
                    modalities = {
                      input = [
                        "text"
                        "image"
                      ];
                      output = [ "text" ];
                    };
                  };
                  "gpt-5.6-luna" = {
                    name = "GPT-5.6 Luna";
                    limit = {
                      context = 400000;
                      output = 128000;
                    };
                    modalities = {
                      input = [
                        "text"
                        "image"
                      ];
                      output = [ "text" ];
                    };
                  };
                  "gemini-3.1-pro-low" = {
                    name = "Gemini 3.1 Pro Low";
                    limit = {
                      context = 400000;
                      output = 128000;
                    };
                    modalities = {
                      input = [
                        "text"
                        "image"
                      ];
                      output = [ "text" ];
                    };
                  };
                  "gemini-3.7-flash-high" = {
                    name = "Gemini 3.7 Flash High";
                    limit = {
                      context = 400000;
                      output = 128000;
                    };
                    modalities = {
                      input = [
                        "text"
                        "image"
                      ];
                      output = [ "text" ];
                    };
                  };
                };
              };
              ollama = {
                options.baseURL = "https://ollama.chn.moe/v1";
                models = {
                  "hf.co/unsloth/Qwen3.8-27B-GGUF:UD-Q4_K_M" = {
                    name = "Qwen3.8 27B (UD-Q4_K_M)";
                    limit = {
                      context = 262144;
                      output = 131072;
                    };
                    modalities = {
                      input = [
                        "text"
                        "image"
                      ];
                      output = [ "text" ];
                    };
                  };
                };
              };
            };
            plugin = [
              "@mohak34/opencode-notifier@0.2.8"
              "@vectorize-io/opencode-hindsight"
            ];
            autoupdate = false;
            mcp = {
              dockerhub = {
                type = "local";
                command = [ (lib.getExe pkgs.localPkgs.dockerhub-mcp) ];
              };
              openalex = {
                type = "local";
                command = [ (lib.getExe pkgs.python3Packages.alex-mcp) ];
              };
              mineru = {
                type = "local";
                command = [ (lib.getExe pkgs.python3Packages.mineru-mcp) ];
              };
              nixos = {
                type = "local";
                command = [ (lib.getExe pkgs.mcp-nixos) ];
              };
              translate = {
                type = "local";
                command = [
                  (lib.getExe pkgs.localPkgs.translate-mcp)
                  "-transport"
                  "stdio"
                  "-config"
                  "${./translate-mcp.yaml}"
                ];
              };
              github = {
                type = "remote";
                url = "https://api.githubcopilot.com/mcp/";
                oauth = false;
                headers.Authorization = "Bearer {file:${config.nixos.system.sops.secrets."opencode/github".path}}";
              };
              agent-browser = {
                type = "local";
                command = [
                  (lib.getExe self.inputs.llm-agents.packages.x86_64-linux.agent-browser)
                  "mcp"
                  "--tools"
                  "core,tabs"
                ];
              };
            };
          };
        };
        catppuccin.opencode.enable = true;
      };
    }
  );
}
