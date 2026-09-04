{
  config,
  pkgs,
  lib,
  self,
  ...
}:
{
  config = {
    services = {
      hermes-agent = {
        enable = true;
        configFile = pkgs.writeText "config.yaml" (
          builtins.toJSON {
            memory.provider = "hindsight";
            model = {
              default = "gemini-3.7-flash-high";
              provider = "cliproxyapi";
            };
            providers.cliproxyapi = {
              base_url = "https://cliproxyapi.chn.moe/v1";
              key_env = "CLIPROXYAPI_API_KEY";
              system_prompt_mode = "user";
            };
            gateway.platforms = {
              api_server = {
                enabled = true;
                extra = {
                  port = 9090;
                  host = "127.0.0.1";
                };
              };
            };
            mcp_servers = {
              dockerhub = {
                command = lib.getExe pkgs.localPkgs.dockerhub-mcp;
              };
              openalex = {
                command = lib.getExe pkgs.python3Packages.alex-mcp;
                env.OPENALEX_MAILTO = "chn@chn.moe";
              };
              mineru = {
                command = lib.getExe pkgs.python3Packages.mineru-mcp;
                env.MINERU_API_KEY = "\${MINERU_API_KEY}";
              };
              nixos = {
                command = lib.getExe pkgs.mcp-nixos;
              };
              qdrant = {
                command = lib.getExe pkgs.localPkgs.mcp-server-qdrant;
                timeout = 300;
                env = {
                  QDRANT_URL = "https://qdrant.chn.moe:443";
                  QDRANT_API_KEY = "\${QDRANT_API_KEY}";
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
                  "${self}/nixosModules/packages/opencode/translate-mcp.yaml"
                ];
                env.CLIPROXYAPI_API_KEY = "\${CLIPROXYAPI_API_KEY}";
              };
              agent-browser = {
                command = lib.getExe self.inputs.llm-agents.packages.x86_64-linux.agent-browser;
                args = [
                  "mcp"
                  "--tools"
                  "core,tabs"
                ];
              };
              github = {
                url = "https://api.githubcopilot.com/mcp/";
                headers.Authorization = "Bearer \${MCP_GITHUB_TOKEN}";
              };
            };
          }
        );
        extraDependencyGroups = [
          "hindsight"
        ];
        environmentFiles = [ config.nixos.system.sops.templates."hermes.env".path ];
        # authFile = ./auth.json;
        # authFileForceOverwrite = true;
        addToSystemPackages = true;
        createUser = false;
      };
    };
    systemd.services.hermes-agent.restartTriggers = [
      (builtins.readFile config.services.hermes-agent.configFile)
      config.nixos.system.sops.templates."hermes.env".content
    ];
    systemd.services.hermes-dashboard = {
      description = "Hermes Agent Web Dashboard";
      wantedBy = [ "multi-user.target" ];
      after = [
        "network.target"
        "hermes-agent.service"
      ];
      wants = [ "hermes-agent.service" ];
      restartTriggers = [
        config.nixos.system.sops.templates."hermes.env".content
      ];
      environment = {
        HOME = config.services.hermes-agent.stateDir;
        HERMES_HOME = "${config.services.hermes-agent.stateDir}/.hermes";
      };
      serviceConfig = {
        User = config.services.hermes-agent.user;
        Group = config.services.hermes-agent.group;
        WorkingDirectory = config.services.hermes-agent.workingDirectory;
        EnvironmentFile = [ config.nixos.system.sops.templates."hermes.env".path ];
        ExecStart =
          let
            hermesPkg = config.services.hermes-agent.package.override {
              inherit (config.services.hermes-agent) extraDependencyGroups extraPythonPackages;
            };
          in
          "${hermesPkg}/bin/hermes dashboard --no-open --host 0.0.0.0 --port 9119";
        Restart = "always";
        RestartSec = 5;
      };
    };
    nixos = {
      services.nginx.https."hermes.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:9119";
      system.sops = {
        templates."hermes.env" = {
          owner = "hermes";
          group = "hermes";
          content =
            let
              inherit (config.nixos.system.sops) placeholder;
            in
            ''
              API_SERVER_KEY=${placeholder."hermes/api_server_token"}
              HERMES_MEDIA_ALLOW_DIRS=/var/lib/hermes/workspace
              HINDSIGHT_MODE=cloud
              HINDSIGHT_API_URL=https://hindsight.chn.moe
              HINDSIGHT_API_KEY=${placeholder."hindsight/password"}
              HINDSIGHT_BANK_ID=chn
              CLIPROXYAPI_API_KEY=${placeholder."opencode/cliproxyapi"}
              HERMES_DASHBOARD_BASIC_AUTH_USERNAME=admin
              HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=${placeholder."hermes/dashboard"}
              HERMES_DASHBOARD_PUBLIC_URL=https://hermes.chn.moe
              MINERU_API_KEY=${placeholder."opencode/mineru"}
              QDRANT_API_KEY=${placeholder."qdrant/api_key"}
              MCP_GITHUB_TOKEN=${placeholder."opencode/github"}
            '';
        };
        secrets = {
          "hermes/api_server_token".owner = "chn";
          "hermes/dashboard" = { };
          "hindsight/password" = { };
          "opencode/mineru" = { };
          "qdrant/api_key" = { };
          "opencode/github" = { };
        };
      };
    };
    users = {
      users.hermes = {
        uid = config.nixos.user.uid.hermes;
        group = "hermes";
        home = config.services.hermes-agent.stateDir;
        createHome = true;
        isSystemUser = true;
        shell = pkgs.bashInteractive;
      };
      groups.hermes.gid = config.nixos.user.gid.hermes;
    };
    home-manager.users.chn = { pkgs, ... }: {
      programs.aichat = {
        enable = true;
        package = pkgs.symlinkJoin {
          name = "aichat-wrapped";
          paths = [ pkgs.aichat ];
          nativeBuildInputs = [ pkgs.makeWrapper ];
          postBuild = ''
            wrapProgram $out/bin/aichat \
              --run 'export HERMES_API_KEY=$(cat ${
                config.nixos.system.sops.secrets."hermes/api_server_token".path
              })'
          '';
        };
        settings = {
          clients = [
            {
              type = "openai";
              name = "hermes";
              api_base = "http://127.0.0.1:9090/v1";
            }
          ];
        };
      };
    };
  };
}
