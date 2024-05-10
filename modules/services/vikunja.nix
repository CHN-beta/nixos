inputs:
{
  options.nixos.services.vikunja = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    autoStart = mkOption { type = types.bool; default = true; };
    port = mkOption { type = types.ints.unsigned; default = 3456; };
    hostname = mkOption { type = types.nonEmptyStr; default = "vikunja.chn.moe"; };
  };
  config = let inherit (inputs.config.nixos.services) vikunja; in inputs.lib.mkIf vikunja.enable
  {
    services.vikunja =
    {
      enable = true;
      environmentFiles = [ inputs.config.sops.templates."vikunja.env".path ];
      settings =
      {
        service.timezone = "Asia/Shanghai";
        mailer = { enable = true; host = "mail.chn.moe"; username = "bot@chn.moe"; fromemail = "bot@chn.moe"; };
        defaultsettings.discoverable_by_email = true;
      };
      inherit (vikunja) port;
      frontendScheme = "https";
      frontendHostname = vikunja.hostname;
      database.type = "postgres";
    };
    sops =
    {
      templates."vikunja.env".content = let placeholder = inputs.config.sops.placeholder; in
      ''
        VIKUNJA_SERVICE_JWTSECRET=${placeholder."vikunja/jwtsecret"}
        VIKUNJA_DATABASE_PASSWORD=${placeholder."postgresql/vikunja"}
        VIKUNJA_MAILER_PASSWORD=${placeholder."mail/bot"}
      '';
      secrets = { "vikunja/jwtsecret" = {}; "mail/bot" = {}; };
    };
    systemd.services.vikunja-api.enable = vikunja.autoStart;
    nixos.services =
    {
      postgresql.instances.vikunja = {};
      nginx = { enable = true; https.${vikunja.hostname}.global.configName = vikunja.hostname; };
    };
  };
}
