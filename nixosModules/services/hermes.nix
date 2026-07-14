{
  lib,
  config,
  pkgs,
  self,
  ...
}:
{
  options.nixos.services.hermes = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule { });
    default = null;
  };
  config =
    let
      inherit (config.nixos.services) hermes;
    in
    lib.mkIf (hermes != null) {
      services.hermes-agent = {
        enable = true;
        settings = {
          model.default = "gemini-3.1-flash-lite";
          providers.antigravity = {
            api_key = "mock";
            base_url = "http://127.0.0.1:8999/v1";
          };
          plugins.enabled = [ "antigravity_mrhisyammm" ];
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
        environment = {
          HERMES_MEDIA_ALLOW_DIRS = "/var/lib/hermes/workspace";
        };
        # authFile = ./auth.json;
        # authFileForceOverwrite = true;
        # mcpServers = {};
        addToSystemPackages = true;
        createUser = false;
      };
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
            '';
        };
        secrets = {
          "hermes/gemini" = { };
          "hermes/tgbot" = { };
          "telegram/user/chn" = { };
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
    };
}
