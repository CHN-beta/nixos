{ lib, config, ... }:
{
  options.nixos.services.peertube = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.submodule {
        options = {
          hostname = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "peertube.chn.moe";
          };
        };
      }
    );
    default = null;
  };
  config =
    let
      inherit (config.nixos.services) peertube;
    in
    lib.mkIf (peertube != null) {
      services.peertube = {
        enable = true;
        localDomain = peertube.hostname;
        listenHttp = 5046;
        listenWeb = 443;
        enableWebHttps = true;
        serviceEnvironmentFile = config.nixos.system.sops.templates."peertube/env".path;
        secrets.secretsFile = config.nixos.system.sops.secrets."peertube/secrets".path;
        configureNginx = true;
        database = {
          createLocally = true;
          host = "127.0.0.1";
          passwordFile = config.nixos.system.sops.secrets."peertube/postgresql".path;
        };
        redis = {
          host = "127.0.0.1";
          port = 7599;
          passwordFile = config.nixos.system.sops.secrets."redis/peertube".path;
        };
        smtp.passwordFile = config.nixos.system.sops.secrets."peertube/smtp".path;
        settings.smtp = {
          host = "mail.chn.moe";
          username = "bot@chn.moe";
          from_address = "bot@chn.moe";
        };
      };
      nixos = {
        system.sops = {
          templates."peertube/env".content = ''
            PT_INITIAL_ROOT_PASSWORD=${config.nixos.system.sops.placeholder."peertube/password"}
          '';
          secrets = {
            "peertube/postgresql" = {
              owner = config.services.peertube.user;
              key = "postgresql/peertube";
            };
            "peertube/password" = { };
            "peertube/secrets".owner = config.services.peertube.user;
            "peertube/smtp" = {
              owner = config.services.peertube.user;
              key = "mail/bot";
            };
          };
        };
        services = {
          nginx.https.${peertube.hostname}.global.configName = peertube.hostname;
          postgresql.instances.peertube = { };
          redis.instances.peertube.port = 7599;
        };
      };
      systemd.services.peertube.after = [ "redis-peertube.service" ];
    };
}
