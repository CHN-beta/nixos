{ lib, config, ... }:
{
  options.nixos.services.vikunja = lib.mkOption
  {
    type = lib.types.nullOr (lib.types.submodule { options =
    {
      hostname = lib.mkOption { type = lib.types.nonEmptyStr; default = "vikunja.chn.moe"; };
    };});
    default = null;
  };
  config = let inherit (config.nixos.services) vikunja; in lib.mkIf (vikunja != null)
  {
    services.vikunja =
    {
      enable = true;
      environmentFiles = [ config.nixos.system.sops.templates."vikunja.env".path ];
      settings =
      {
        service.timezone = "Asia/Shanghai";
        mailer = { enable = true; host = "mail.chn.moe"; username = "bot@chn.moe"; fromemail = "bot@chn.moe"; };
        defaultsettings.discoverable_by_email = true;
      };
      port = 3456;
      frontendScheme = "https";
      frontendHostname = vikunja.hostname;
      database.type = "postgres";
    };
    nixos =
    {
      services =
      {
        postgresql.instances.vikunja = {};
        nginx.https.${vikunja.hostname}.location."/".proxy.upstream = "http://127.0.0.1:3456";
      };
      system.sops =
      {
        templates."vikunja.env".content = let inherit (config.sops) placeholder; in
        ''
          VIKUNJA_SERVICE_JWTSECRET=${placeholder."vikunja/jwtsecret"}
          VIKUNJA_DATABASE_PASSWORD=${placeholder."postgresql/vikunja"}
          VIKUNJA_MAILER_PASSWORD=${placeholder."mail/bot"}
        '';
        secrets = { "vikunja/jwtsecret" = {}; "mail/bot" = {}; };
      };
    };
  };
}
