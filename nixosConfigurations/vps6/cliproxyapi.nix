{ config, pkgs, ... }:
{
  config = {
    services.cliproxyapi = {
      enable = true;
      settings = {
        config-version = 8;
        server = {
          host = "127.0.0.1";
          port = 8317;
          commercial-mode = false;
        };
        management = {
          allow-remote = true;
          secret-key._secret = config.nixos.system.sops.secrets."cliproxyapi/management".path;
          disable-control-panel = true;
          panel-github-repository = "https://github.com/router-for-me/Cli-Proxy-API-Management-Center";
        };
        oauth = {
          auth-dir = "/var/lib/cliproxyapi/.cli-proxy-api";
          model-alias.antigravity = [
            {
              name = "gemini-4-argon-high";
              alias = "gemini-4-argon";
            }
            {
              name = "gemini-3.8-flash-high";
              alias = "gemini-3.8-flash";
            }
            {
              name = "claude-opus-5-5-high";
              alias = "claude-opus-5-5";
            }
            {
              name = "claude-sonnet-5-5-high";
              alias = "claude-sonnet-5-5";
            }
          ];
          providers = {
            aistudio.ws-auth = true;
            antigravity = {
              sensitive-words = [ "Nous Research" ];
              antigravity-credits = true;
            };
          };
        };
        access.api-keys = [
          {
            key._secret = config.nixos.system.sops.secrets."straycat/cliproxyapi".path;
            name = "self";
          }
        ];
        observability = {
          logs = {
            debug = false;
            logging-to-file = false;
            logs-max-total-size-mb = 0;
            error-logs-max-files = 10;
          };
          usage = {
            usage-statistics-enabled = true;
            redis-usage-queue-retention-seconds = 60;
            postgres-dsn._secret = config.nixos.system.sops.templates."cliproxyapi/postgres-dsn".path;
          };
          pprof = {
            enable = false;
            addr = "127.0.0.1:8316";
          };
        };
        requests = {
          proxy-url = "";
          passthrough-headers = false;
          nonstream-keepalive-interval = 0;
        };
        routing = {
          strategy = "round-robin";
          session-affinity = true;
          session-affinity-ttl = "1h";
          session-affinity-subagents = true;
          session-affinity-rebind-on = "quota";
          force-model-prefix = false;
          retry = {
            request-retry = 3;
            max-retry-credentials = 1;
            max-retry-interval = 30;
          };
          cooldown = {
            disable-cooling = false;
            transient-error-cooldown-seconds = -1;
          };
        };
        credentials.concurrency = {
          cpa-heartbeat-timeout = "3s";
          cpa-cancel-bound = "5s";
          reclaim-grace = "5s";
          cleanup-interval = "5s";
          release-flush-interval = "250ms";
          release-max-backoff = "2s";
          busy-retry-min = "250ms";
          busy-retry-max = "1s";
          max-limit = 1000000;
        };
        credentials.in-flight = {
          snapshot-interval = "2s";
          stale-after = "10s";
          max-part-bytes = 262144;
          max-part-count = 64;
          max-revision-bytes = 16777216;
          max-aggregate-groups = 100000;
          max-details = 10000;
          max-string-bytes = 256;
          staging-retention = "1m";
        };
        api-keys = {
          gemini = [
            {
              name = "aistudio";
              base-url = "https://generativelanguage.googleapis.com";
              priority = -1;
              keys = [
                {
                  api-key._secret = config.nixos.system.sops.secrets."cliproxyapi/gemini".path;
                }
              ];
            }
          ];
          openai-compatibility = [
            {
              name = "deepseek";
              base-url = "https://api.deepseek.com";
              priority = -1;
              keys = [
                {
                  api-key._secret = config.nixos.system.sops.secrets."straycat/deepseek".path;
                }
              ];
              models = [
                {
                  name = "deepseek-flash";
                }
              ];
            }
          ];
        };
      };
    };
    systemd.services.cliproxyapi = {
      after = [ "postgresql.service" ];
      requires = [ "postgresql.service" ];
    };
    nixos = {
      services = {
        postgresql.instances.cliproxyapi = { };
        nginx.https."cliproxyapi.chn.moe" = {
          global.extraConfig = ''
            # Forward streaming responses immediately without buffering or caching.
            proxy_buffering off;
            proxy_cache off;
          '';
          location = {
            "/".proxy.upstream = "http://127.0.0.1:8317";
            "/management.html".static.root = "${pkgs.cliproxyapi}/share/cliproxyapi";
          };
        };
      };
      system.sops = {
        secrets = {
          "cliproxyapi/management" = { };
          "cliproxyapi/gemini" = { };
          "straycat/cliproxyapi" = { };
          "straycat/deepseek" = { };
        };
        templates."cliproxyapi/postgres-dsn".content = "postgres://cliproxyapi:${
          config.nixos.system.sops.placeholder."postgresql/cliproxyapi"
        }@127.0.0.1:5432/cliproxyapi?sslmode=disable";
      };
    };
  };
}
