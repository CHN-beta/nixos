{ config, ... }:
{
  config = {
    services.cliproxyapi = {
      enable = true;
      settings = {
        host = "127.0.0.1";
        port = 8317;
        remote-management = {
          allow-remote = true;
          secret-key._secret = config.nixos.system.sops.secrets."cliproxyapi/management".path;
          disable-control-panel = false;
          panel-github-repository = "https://github.com/router-for-me/Cli-Proxy-API-Management-Center";
        };
        auth-dir = "/var/lib/cliproxyapi/.cli-proxy-api";
        api-keys = [ { _secret = config.nixos.system.sops.secrets."straycat/cliproxyapi".path; } ];
        debug = false;
        pprof = {
          enable = false;
          addr = "127.0.0.1:8316";
        };
        commercial-mode = false;
        logging-to-file = false;
        logs-max-total-size-mb = 0;
        error-logs-max-files = 10;
        usage-statistics-enabled = false;
        proxy-url = "";
        force-model-prefix = false;
        passthrough-headers = false;
        request-retry = 3;
        max-retry-credentials = 0;
        max-retry-interval = 30;
        disable-cooling = false;
        quota-exceeded = {
          switch-project = true;
          switch-preview-model = true;
          antigravity-credits = true;
        };
        routing.strategy = "round-robin";
        ws-auth = false;
        enable-gemini-cli-endpoint = false;
        nonstream-keepalive-interval = 0;
        antigravity.sensitive-words = [ "Nous Research" ];
        credential-concurrency = {
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
        credential-in-flight = {
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
        redis-usage-queue-retention-seconds = 60;
        gemini-api-key = [ ];
        openai-compatibility = [ ];
      };
    };

    nixos = {
      system.sops.secrets."cliproxyapi/management" = { };
      services.nginx.https."cliproxyapi.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:8317";
    };
  };
}
