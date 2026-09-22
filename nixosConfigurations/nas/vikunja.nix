{ config, ... }:
let
  port = 3456;
in
{
  services.vikunja = {
    enable = true;
    environmentFiles = [ config.nixos.system.sops.templates."vikunja.env".path ];
    settings = {
      service.timezone = "Asia/Shanghai";
      mailer = {
        enable = true;
        host = "mail.chn.moe";
        username = "bot@chn.moe";
        fromemail = "bot@chn.moe";
      };
      defaultsettings.discoverable_by_email = true;
    };
    inherit port;
    frontendScheme = "https";
    frontendHostname = "vikunja.chn.moe";
    database.type = "postgres";
  };

  systemd.services.vikunja = {
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
  };

  nixos = {
    services = {
      postgresql.instances.vikunja = { };
      nginx.https."vikunja.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:${toString port}";
    };
    system.sops = {
      templates."vikunja.env" = {
        content =
          let
            inherit (config.nixos.system.sops) placeholder;
          in
          ''
            VIKUNJA_SERVICE_JWTSECRET=${placeholder."vikunja/jwtsecret"}
            VIKUNJA_DATABASE_PASSWORD=${placeholder."postgresql/vikunja"}
            VIKUNJA_MAILER_PASSWORD=${placeholder."mail/bot"}
          '';
      };
      secrets = {
        "vikunja/jwtsecret" = { };
        "mail/bot" = { };
      };
    };
  };
}
