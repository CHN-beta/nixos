inputs:
{
  options.nixos.services.gitea = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.str; default = "git.chn.moe"; };
  };
  config =
    let
      inherit (inputs.config.nixos.services) gitea;
      inherit (inputs.lib) mkIf;
    in mkIf gitea.enable
    {
      services.gitea =
      {
        enable = true;
        lfs.enable = true;
        mailerPasswordFile = inputs.config.sops.secrets."gitea/mail".path;
        database =
        {
          createDatabase = false;
          type = "postgres";
          passwordFile = inputs.config.sops.secrets."gitea/db".path;
        };
        settings =
        {
          session =
          {
            COOKIE_SECURE = true;
          };
          server =
          {
            SSH_PORT = 2222;
            ROOT_URL = "https://${gitea.hostname}";
            DOMAIN = gitea.hostname;
            HTTP_PORT = 3002;
          };
          mailer =
          {
            ENABLED = true;
            FROM = "bot@chn.moe";
            PROTOCOL = "smtps";
            SMTP_ADDR = "mail.chn.moe";
            SMTP_PORT = 465;
            USER = "bot@chn.moe";
          };
        };
      };
      nixos.services =
      {
        nginx =
        {
          enable = true;
          https."${gitea.hostname}".location."/".proxy.upstream = "http://127.0.0.1:3002";
        };
        postgresql.instances.gitea = {};
      };
      sops.secrets =
      {
        "gitea/mail" = { owner = "gitea"; key = "mail/bot"; };
        "gitea/db" = { owner = "gitea"; key = "postgresql/gitea"; };
        "mail/bot" = {};
      };
    };
}
