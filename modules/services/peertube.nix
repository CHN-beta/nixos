inputs:
{
  options.nixos.services.peertube = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      hostname = mkOption { type = types.nonEmptyStr; default = "peertube.chn.moe"; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) peertube; in inputs.lib.mkIf (peertube != null)
  {
    services.peertube =
    {
      enable = true;
      localDomain = peertube.hostname;
      listenHttp = 5046;
      listenWeb = 443;
      enableWebHttps = true;
      serviceEnvironmentFile = inputs.config.sops.templates."peertube/env".path;
      secrets.secretsFile = inputs.config.sops.secrets."peertube/secrets".path;
      configureNginx = true;
      database =
      {
        createLocally = true;
        host = "127.0.0.1";
        passwordFile = inputs.config.sops.secrets."peertube/postgresql".path;
      };
      redis =
      {
        host = "127.0.0.1";
        port = 7599;
        passwordFile = inputs.config.sops.secrets."redis/peertube".path;
      };
      smtp.passwordFile = inputs.config.sops.secrets."peertube/smtp".path;
      settings.smtp =
      {
        host = "mail.chn.moe";
        username = "bot@chn.moe";
        from_address = "bot@chn.moe";
      };
    };
    sops =
    {
      templates."peertube/env".content =
      ''
        PT_INITIAL_ROOT_PASSWORD=${inputs.config.sops.placeholder."peertube/password"}
      '';
      secrets =
      {
        "peertube/postgresql" = { owner = inputs.config.services.peertube.user; key = "postgresql/peertube"; };
        "peertube/password" = {};
        "peertube/secrets".owner = inputs.config.services.peertube.user;
        "peertube/smtp" = { owner = inputs.config.services.peertube.user; key = "mail/bot"; };
      };
    };
    nixos.services =
    {
      nginx = { enable = true; https.${peertube.hostname}.global.configName = peertube.hostname; };
      postgresql.instances.peertube = {};
      redis.instances.peertube.port = 7599;
    };
    systemd.services.peertube.after = [ "redis-peertube.service" ];
  };
}
