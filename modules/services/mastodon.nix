inputs:
{
  options.nixos.services.mastodon = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      hostname = mkOption { type = types.nonEmptyStr; default = "mastodon.chn.moe"; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) mastodon; in inputs.lib.mkIf (mastodon != null)
  {
    services.mastodon =
    {
      enable = true;
      localDomain = mastodon.hostname;
      configureNginx = true;
      streamingProcesses = 1;
      smtp =
      {
        createLocally = false;
        authenticate = true;
        host = "mail.chn.moe";
        port = 465;
        fromAddress = "bot@chn.moe";
        user = "bot@chn.moe";
        passwordFile = inputs.config.nixos.system.sops.secrets."mastodon/smtp".path;
      };
      extraConfig = { SMTP_TLS = "true"; };
      database =
      {
        createLocally = false;
        host = "127.0.0.1";
        port = 5432;
        name = "mastodon";
        user = "mastodon";
        passwordFile = inputs.config.nixos.system.sops.secrets."mastodon/postgresql".path;
      };
    };
    # mastodon's configureNginx sets recommendedProxySettings = true, but this repo uses false globally
    services.nginx.recommendedProxySettings = inputs.lib.mkForce false;
    nixos =
    {
      system.sops.secrets =
      {
        "mastodon/postgresql" = { owner = "mastodon"; key = "postgresql/mastodon"; };
        "mastodon/smtp" = { owner = "mastodon"; key = "mail/bot"; };
      };
      services =
      {
        postgresql.instances.mastodon = {};
        nginx.https.${mastodon.hostname}.global.configName = mastodon.hostname;
      };
    };
    systemd.services.mastodon-init-db =
    {
      requires = [ "postgresql.service" ];
      after = [ "postgresql.service" ];
    };
  };
}
