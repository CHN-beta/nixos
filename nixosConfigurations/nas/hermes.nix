{
  config,
  pkgs,
  self,
  ...
}:
{
  config = {
    services.hermes-agent = {
      enable = true;
      settings = {
        model = {
          default = "gemini-3.5-pro";
          provider = "antigravity";
        };
        providers.antigravity = {
          api_key = "mock";
          base_url = "http://127.0.0.1:8999/v1";
        };
        plugins.enabled = [ "antigravity_mrhisyammm" ];
        gateway.platforms.api_server = {
          enabled = true;
          extra = {
            port = 9090;
            host = "127.0.0.1";
          };
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
      extraDependencyGroups = [ "messaging" ];
      environmentFiles = [ config.nixos.system.sops.templates."hermes.env".path ];
      # authFile = ./auth.json;
      # authFileForceOverwrite = true;
      # mcpServers = {};
      addToSystemPackages = true;
      createUser = false;
    };
    systemd.services.hermes-agent.restartTriggers = [
      (builtins.toJSON config.services.hermes-agent.settings)
      config.nixos.system.sops.templates."hermes.env".content
    ];
    nixos.system.sops = {
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
          '';
      };
      secrets = {
        "hermes/gemini" = { };
        "hermes/tgbot" = { };
        "telegram/user/chn" = { };
        "hermes/api_server_token".owner = "chn";
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
