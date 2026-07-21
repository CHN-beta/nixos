{
  config,
  pkgs,
  self,
  ...
}:
{
  config = {
    services = {
      hermes-agent = {
        enable = true;
        settings = {
          memory.provider = "mem0";
          model = {
            default = "gemini-3.5-pro";
            provider = "antigravity";
          };
          providers.antigravity = {
            api_key = "mock";
            base_url = "http://127.0.0.1:8999/v1";
          };
          plugins.enabled = [ "antigravity_mrhisyammm" ];
          gateway.platforms = {
            api_server = {
              enabled = true;
              extra = {
                port = 9090;
                host = "127.0.0.1";
              };
            };
            matrix.enabled = true;
          };
        };
        extraPlugins = [
          (pkgs.stdenv.mkDerivation {
            name = "antigravity_mrhisyammm";
            src = self.inputs.hermes-antigravity-auth;
            installPhase = ''
              mkdir -p $out
              cp -r plugins/antigravity_mrhisyammm/* $out/
            '';
          })
          (pkgs.stdenv.mkDerivation {
            name = "antigravity-provider";
            src = self.inputs.hermes-antigravity-auth;
            installPhase = ''
              mkdir -p $out
              cp -r plugins/model-providers/antigravity/* $out/
            '';
          })
        ];
        extraDependencyGroups = [
          "messaging"
          "matrix"
          "mem0"
        ];
        environmentFiles = [ config.nixos.system.sops.templates."hermes.env".path ];
        # authFile = ./auth.json;
        # authFileForceOverwrite = true;
        # mcpServers = {};
        addToSystemPackages = true;
        createUser = false;
      };
      ollama.loadModels = [ "mxbai-embed-large" ];
    };
    systemd.services.hermes-agent.restartTriggers = [
      (builtins.toJSON config.services.hermes-agent.settings)
      config.nixos.system.sops.templates."hermes.env".content
    ];
    nixos = {
      system.sops = {
        templates."hermes.env" = {
          owner = "hermes";
          group = "hermes";
          content =
            let
              inherit (config.nixos.system.sops) placeholder;
            in
            ''
              GEMINI_API_KEY=${placeholder."hermes/gemini"}
              TELEGRAM_BOT_TOKEN=${placeholder."hermes/tgbot"}
              TELEGRAM_ALLOWED_USERS=${placeholder."telegram/user/chn"}
              API_SERVER_KEY=${placeholder."hermes/api_server_token"}
              HERMES_MEDIA_ALLOW_DIRS=/var/lib/hermes/workspace
              MATRIX_HOMESERVER=https://matrix.chn.moe
              MATRIX_USER_ID=@hermes:chn.moe
              MATRIX_PASSWORD=${placeholder."hermes/matrix_password"}
              MATRIX_ALLOWED_USERS=@chn:chn.moe
              PGPASSWORD=${placeholder."postgresql/hermes-mem0"}
            '';
        };
        secrets = {
          "hermes/gemini" = { };
          "hermes/tgbot" = { };
          "hermes/matrix_password" = { };
          "telegram/user/chn" = { };
          "hermes/api_server_token".owner = "chn";
        };
      };
      services = {
        postgresql.instances.hermes-mem0.extensions = [ "vector" ];
        ollama = { };
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
