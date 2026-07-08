{
  pkgs,
  lib,
  self,
  config,
  ...
}:
{
  options.nixos.services.gitea = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.submodule {
        options = {
          hostname = lib.mkOption {
            type = lib.types.str;
            default = "git.chn.moe";
          };
          ssh = {
            hostname = lib.mkOption {
              type = lib.types.str;
              default = "ssh.${config.nixos.services.gitea.hostname}";
            };
            port = lib.mkOption {
              type = lib.types.nullOr lib.types.ints.unsigned;
              default = null;
            };
          };
        };
      }
    );
    default = null;
  };
  config =
    let
      inherit (config.nixos.services) gitea;
    in
    lib.mkIf (gitea != null) {
      services = {
        gitea = {
          enable = true;
          lfs.enable = true;
          mailerPasswordFile = config.nixos.system.sops.secrets."gitea/mail".path;
          database = {
            createDatabase = false;
            type = "postgres";
            passwordFile = config.nixos.system.sops.secrets."gitea/db".path;
          };
          settings = {
            session.COOKIE_SECURE = true;
            server = {
              ROOT_URL = "https://${gitea.hostname}";
              DOMAIN = gitea.hostname;
              HTTP_PORT = 3002;
              SSH_DOMAIN = gitea.ssh.hostname;
              SSH_PORT = lib.mkIf (gitea.ssh.port != null) gitea.ssh.port;
              LFS_ALLOW_PURE_SSH = true;
            };
            mailer = {
              ENABLED = true;
              FROM = "bot@chn.moe";
              PROTOCOL = "smtps";
              SMTP_ADDR = "mail.chn.moe";
              SMTP_PORT = 465;
              USER = "bot@chn.moe";
            };
            service.DISABLE_REGISTRATION = true;
            security.LOGIN_REMEMBER_DAYS = 365;
            "git.timeout" = builtins.listToAttrs (
              builtins.map
                (n: {
                  name = n;
                  value = 3600 * 8;
                })
                [
                  "DEFAULT"
                  "MIGRATE"
                  "MIRROR"
                  "CLONE"
                  "PULL"
                  "GC"
                ]
            );
            "cron.git_gc_repos" = {
              ENABLED = true;
              SCHEDULE = "@monthly";
              TIMEOUT = "2h";
            };
            "cron.gc_lfs" = {
              ENABLED = true;
              SCHEDULE = "@monthly";
              NUMBER_TO_CHECK_PER_REPO = 0;
            };
          };
        };
        anubis.instances.gitea = {
          settings = {
            OG_PASSTHROUGH = true;
            TARGET = "http://127.0.0.1:3002";
            BIND_NETWORK = "tcp";
            BIND = "127.0.0.1:7757";
            WEBMASTER_EMAIL = "chn@chn.moe";
            SERVE_ROBOTS_TXT = true;
            METRICS_BIND = "/run/anubis/anubis-gitea/anubis-metrics.sock";
          };
          botPolicy = {
            bots = [
              { import = "(data)/meta/default-config.yaml"; }
              {
                name = "allow-git";
                action = "ALLOW";
                expression.any = [
                  ''userAgent.contains("git/")''
                  ''userAgent.contains("Nix/")''
                ];
              }
              {
                name = "challenge-all";
                path_regex = ".*";
                action = "CHALLENGE";
                challenge = {
                  algorithm = "fast";
                  difficulty = 4;
                };
              }
            ];
          };
        };
      };
      nixos = {
        system.sops.secrets = {
          "gitea/mail" = {
            owner = "gitea";
            key = "mail/bot";
          };
          "gitea/db" = {
            owner = "gitea";
            key = "postgresql/gitea";
          };
          "mail/bot" = { };
        };
        services = {
          nginx.https.${gitea.hostname}.location = {
            "/".proxy.upstream = "http://127.0.0.1:$proxy_port";
            "/robots.txt".static.root = builtins.toString (
              pkgs.runCommand "robots.txt" { } "mkdir -p $out; cp ${self.inputs.gitea-robots-txt} $out/robots.txt"
            );
          };
          postgresql.instances.gitea = { };
        };
      };
      services.nginx.virtualHosts."https:git.chn.moe".locations."/".extraConfigPre = ''
        # bypass anubis when referer is from https://blog.chn.moe
        valid_referers blog.chn.moe;
        set $proxy_port 3002;
        if ($invalid_referer) {
          set $proxy_port 7757;
        }
      '';
      systemd.services.gitea.path = [ pkgs.git-lfs-transfer ];
    };
}
