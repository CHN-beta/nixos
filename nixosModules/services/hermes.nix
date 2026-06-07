{
  lib,
  config,
  pkgs,
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
        settings.model.default = "gemini-3.1-flash-lite";
        environmentFiles = [ config.nixos.system.sops.templates."hermes.env".path ];
        # environment = {};
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
