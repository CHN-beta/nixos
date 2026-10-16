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
          providers = {
            aistudio.ws-auth = true;
            antigravity = {
              sensitive-words = [ "Nous Research" ];
              antigravity-credits = true;
            };
          };
        };
        access.api-keys = [ { _secret = config.nixos.system.sops.secrets."straycat/cliproxyapi".path; } ];
        observability = {
          logs = {
            debug = false;
            logging-to-file = false;
            logs-max-total-size-mb = 0;
            error-logs-max-files = 10;
          };
          usage = {
            usage-statistics-enabled = false;
            redis-usage-queue-retention-seconds = 60;
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
          force-model-prefix = false;
          retry = {
            request-retry = 3;
            max-retry-credentials = 0;
            max-retry-interval = 30;
          };
          cooldown.disable-cooling = false;
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
        api-keys.gemini = [ ];
      };
    };

    nixos = {
      system.sops.secrets."cliproxyapi/management" = { };
      services.nginx.https."cliproxyapi.chn.moe" = {
        global.extraConfig = ''
          # Forward streaming responses immediately without buffering or caching.
          proxy_buffering off;
          proxy_cache off;
        '';
        location = {
          "/".proxy.upstream = "http://127.0.0.1:8317";
          "/management.html".static.root =
            let
              managementHtml = pkgs.fetchurl {
                url = "https://github.com/router-for-me/Cli-Proxy-API-Management-Center/releases/download/v1.26.4/management.html";
                sha256 = "sha256-g8ZHdet6t3t1fCN0aMtx3MCqEt4U08znTpTo0375u9k=";
              };
              root = pkgs.runCommand "management" { } ''
                mkdir -p $out
                cp ${managementHtml} $out/management.html
              '';
            in
            "${root}";
        };
      };
    };
  };
}
