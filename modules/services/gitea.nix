inputs:
{
  options.nixos.services.gitea = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.str; default = "git.chn.moe"; };
    ssh = mkOption
    {
      type = types.nullOr (types.submodule { options =
      {
        hostname = mkOption { type = types.str; default = "ssh.${inputs.config.nixos.services.gitea.hostname}"; };
        port = mkOption { type = types.nullOr types.ints.unsigned; default = null; };
      };});
      default = null;
    };
  };
  config = let inherit (inputs.config.nixos.services) gitea; in inputs.lib.mkIf gitea.enable
  {
    services.gitea =
    {
      enable = true;
      lfs.enable = true;
      mailerPasswordFile = inputs.config.sops.secrets."gitea/mail".path;
      database =
        { createDatabase = false; type = "postgres"; passwordFile = inputs.config.sops.secrets."gitea/db".path; };
      settings =
      {
        session.COOKIE_SECURE = true;
        server =
        {
          ROOT_URL = "https://${gitea.hostname}";
          DOMAIN = gitea.hostname;
          HTTP_PORT = 3002;
          SSH_DOMAIN = inputs.lib.mkIf (gitea.ssh != null) gitea.ssh.hostname;
          SSH_PORT = inputs.lib.mkIf ((gitea.ssh.port or null) != null) gitea.ssh.port;
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
        service.DISABLE_REGISTRATION = true;
        security.LOGIN_REMEMBER_DAYS = 365;
      };
    };
    nixos.services =
    {
      nginx =
      {
        enable = true;
        https.${gitea.hostname}.location =
        {
          "/".proxy.upstream = "http://127.0.0.1:3002";
          "/robots.txt".static.root =
            let robotsFile = inputs.pkgs.fetchurl
            {
              url = "https://gitea.com/robots.txt";
              sha256 = "144c5s3la4a85c9lygcnxhbxs3w5y23bkhhqx69fbp9yiqyxdkk2";
            };
            in "${inputs.pkgs.runCommand "robots.txt" {} "mkdir -p $out; cp ${robotsFile} $out/robots.txt"}";
        };
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
