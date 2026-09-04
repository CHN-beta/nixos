{
  config,
  pkgs,
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
              matrix.enabled = true;
            };
          }
        );
        extraDependencyGroups = [
          "messaging"
          "matrix"
          "hindsight"
        ];
        environmentFiles = [ config.nixos.system.sops.templates."hermes.env".path ];
        # authFile = ./auth.json;
        # authFileForceOverwrite = true;
        # mcpServers = {};
        addToSystemPackages = true;
        createUser = false;
      };
    };
    systemd.services.hermes-agent.restartTriggers = [
      (builtins.toJSON config.services.hermes-agent.settings)
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
          "${hermesPkg}/bin/hermes dashboard --no-open --host 127.0.0.1 --port 9119";
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
              TELEGRAM_BOT_TOKEN=${placeholder."hermes/tgbot"}
              TELEGRAM_ALLOWED_USERS=${placeholder."telegram/user/chn"}
              API_SERVER_KEY=${placeholder."hermes/api_server_token"}
              HERMES_MEDIA_ALLOW_DIRS=/var/lib/hermes/workspace
              MATRIX_HOMESERVER=https://matrix.chn.moe
              MATRIX_USER_ID=@hermes:chn.moe
              MATRIX_PASSWORD=${placeholder."hermes/matrix_password"}
              MATRIX_ALLOWED_USERS=@chn:chn.moe
              MATRIX_REQUIRE_MENTION=false
              MATRIX_ENCRYPTION=true
              MATRIX_DEVICE_ID=HERMES_BOT
              MATRIX_HOME_ROOM=${placeholder."hermes/matrix_home"}
              HINDSIGHT_MODE=cloud
              HINDSIGHT_API_URL=https://hindsight.chn.moe
              HINDSIGHT_API_KEY=${placeholder."hindsight/password"}
              HINDSIGHT_BANK_ID=chn
              CLIPROXYAPI_API_KEY=${placeholder."opencode/cliproxyapi"}
              HERMES_DASHBOARD_BASIC_AUTH_USERNAME=admin
              HERMES_DASHBOARD_BASIC_AUTH_PASSWORD=${placeholder."hermes/dashboard"}
              HERMES_DASHBOARD_PUBLIC_URL=https://hermes.chn.moe
            '';
        };
        secrets = {
          "hermes/tgbot" = { };
          "hermes/matrix_password" = { };
          "hermes/matrix_home" = { };
          "hermes/dashboard" = { };
          "telegram/user/chn" = { };
          "hermes/api_server_token".owner = "chn";
          "hindsight/password" = { };
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
