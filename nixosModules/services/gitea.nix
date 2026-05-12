{ pkgs, lib, flakeInputs, config, ... }:
{
  options.nixos.services.gitea = lib.mkOption
  {
    type = lib.types.nullOr (lib.types.submodule { options =
    {
      hostname = lib.mkOption { type = lib.types.str; default = "git.chn.moe"; };
      ssh =
      {
        hostname = lib.mkOption { type = lib.types.str; default = "ssh.${config.nixos.services.gitea.hostname}"; };
        port = lib.mkOption { type = lib.types.nullOr lib.types.ints.unsigned; default = null; };
      };
    };});
    default = null;
  };
  config = let inherit (config.nixos.services) gitea; in lib.mkIf (gitea != null)
  {
    services =
    {
      gitea =
      {
        enable = true;
        lfs.enable = true;
        mailerPasswordFile = config.nixos.system.sops.secrets."gitea/mail".path;
        database =
        {
          createDatabase = false;
          type = "postgres";
          passwordFile = config.nixos.system.sops.secrets."gitea/db".path;
        };
        settings =
        {
          session.COOKIE_SECURE = true;
          server =
          {
            ROOT_URL = "https://${gitea.hostname}";
            DOMAIN = gitea.hostname;
            HTTP_PORT = 3002;
            SSH_DOMAIN = gitea.ssh.hostname;
            SSH_PORT = lib.mkIf (gitea.ssh.port != null) gitea.ssh.port;
            LFS_ALLOW_PURE_SSH = true;
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
          "git.timeout" = builtins.listToAttrs (builtins.map (n: { name = n; value = 3600 * 8; })
            [ "DEFAULT" "MIGRATE" "MIRROR" "CLONE" "PULL" "GC" ]);
          "cron.git_gc_repos" = { ENABLED = true; SCHEDULE = "@monthly"; TIMEOUT = "2h"; };
          "cron.gc_lfs" = { ENABLED = true; SCHEDULE = "@monthly"; NUMBER_TO_CHECK_PER_REPO = 0; };
        };
      };
      anubis.instances.gitea =
      {
        settings =
        {
          OG_PASSTHROUGH = true;
          TARGET = "http://127.0.0.1:3002";
          BIND_NETWORK = "tcp";
          BIND = "127.0.0.1:7757";
          WEBMASTER_EMAIL = "chn@chn.moe";
          SERVE_ROBOTS_TXT = true;
          METRICS_BIND = "/run/anubis/anubis-gitea/anubis-metrics.sock";
        };
        botPolicy.bots =
        [
          { name = "allow-blog-referer"; action = "ALLOW"; headers_regex.Referer = ''.*blog\.chn\.moe.*''; }
          { import = "(data)/meta/default-config.yaml"; }
        ];
      };
    };
    nixos =
    {
      system.sops.secrets =
      {
        "gitea/mail" = { owner = "gitea"; key = "mail/bot"; };
        "gitea/db" = { owner = "gitea"; key = "postgresql/gitea"; };
        "mail/bot" = {};
      };
      services =
      {
        nginx.https.${gitea.hostname}.location =
        {
          "/".proxy.upstream = "http://127.0.0.1:7757";
          "/robots.txt".static.root = builtins.toString
            (pkgs.runCommand "robots.txt" {} "mkdir -p $out; cp ${flakeInputs.gitea-robots-txt} $out/robots.txt");
        };
        postgresql.instances.gitea = {};
      };
    };
    systemd.services.gitea.path = [ pkgs.git-lfs-transfer ];
  };
}
