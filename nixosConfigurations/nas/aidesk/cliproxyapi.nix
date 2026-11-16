{
  config,
  pkgs,
  lib,
  ...
}:
{
  options.nixos.services.cliproxyapi.users = lib.mkOption {
    type = lib.types.listOf lib.types.str;
    default = [ ];
  };
  config =
    let
      inherit (config.nixos.services) cliproxyapi;
    in
    {
      services.cliproxyapi = {
        enable = true;
        settings = {
          config-version = 8;
          server = {
            host = "127.0.0.1";
            port = 8317;
            trusted-proxies = [
              "127.0.0.1"
              "::1"
            ];
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
                name = "gemini-4-hydrogen-xhigh";
                alias = "gemini-4-hydrogen";
              }
              {
                name = "gemini-4-argon-high";
                alias = "gemini-4-argon";
              }
              {
                name = "gemini-4-carbon-high";
                alias = "gemini-4-carbon";
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
          access.api-keys = lib.map (user: {
            key._secret = config.nixos.system.sops.secrets."cliproxyapi/keys/${user}".path;
            name = user;
          }) (cliproxyapi.users ++ [ "infra" ]);
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
              # Client API key billing rates in USD per million tokens. cliproxyapi
              # ships no built-in prices: a model missing here is billed at zero.
              # Entries match in order (case-insensitive `*` globs, first match
              # wins), so keep specific names before broader patterns.
              model-pricing = [
                ## Gemini 4 shared rate card
                {
                  model = "gemini-4-*";
                  input = 0.20;
                  cache-read = 0.01;
                  output = 1.00;
                }
                ## Gemini 3.x / 2.5 flash family
                {
                  model = "gemini-3.8-flash";
                  input = 0.075;
                  cache-read = 0.0075;
                  output = 0.375;
                }
                {
                  model = "gemini-3.7-flash";
                  input = 0.075;
                  cache-read = 0.0075;
                  output = 0.375;
                }
                {
                  model = "gemini-3.6-flash";
                  input = 0.075;
                  cache-read = 0.0075;
                  output = 0.375;
                }
                {
                  model = "gemini-3.5-flash";
                  input = 0.15;
                  cache-read = 0.015;
                  output = 0.75;
                }
                {
                  model = "gemini-3.5-flash-lite";
                  input = 0.03;
                  cache-read = 0.003;
                  output = 0.25;
                }
                {
                  model = "gemini-3-flash";
                  input = 0.05;
                  cache-read = 0.005;
                  output = 0.30;
                }
                {
                  model = "gemini-3-flash-preview";
                  input = 0.05;
                  cache-read = 0.005;
                  output = 0.30;
                }
                {
                  model = "gemini-3.1-flash-lite";
                  input = 0.025;
                  cache-read = 0.0025;
                  output = 0.15;
                }
                {
                  model = "gemini-3.1-flash-lite-preview";
                  input = 0.025;
                  cache-read = 0.0025;
                  output = 0.15;
                }
                {
                  model = "gemini-2.5-flash";
                  input = 0.03;
                  cache-read = 0.003;
                  output = 0.25;
                }
                {
                  model = "gemini-2.5-flash-lite";
                  input = 0.01;
                  cache-read = 0.001;
                  output = 0.04;
                }
                ## Gemini Pro tiered pricing (>200k input tokens)
                {
                  model = "gemini-3.1-pro";
                  input = 0.20;
                  cache-read = 0.02;
                  output = 1.20;
                  tiers = [
                    {
                      min-input-tokens = 200001;
                      input = 0.40;
                      cache-read = 0.04;
                      output = 1.80;
                    }
                  ];
                }
                {
                  model = "gemini-3.1-pro-preview";
                  input = 0.20;
                  cache-read = 0.02;
                  output = 1.20;
                  tiers = [
                    {
                      min-input-tokens = 200001;
                      input = 0.40;
                      cache-read = 0.04;
                      output = 1.80;
                    }
                  ];
                }
                {
                  model = "gemini-3-pro";
                  input = 0.20;
                  cache-read = 0.02;
                  output = 1.20;
                  tiers = [
                    {
                      min-input-tokens = 200001;
                      input = 0.40;
                      cache-read = 0.04;
                      output = 1.80;
                    }
                  ];
                }
                {
                  model = "gemini-3-pro-preview";
                  input = 0.20;
                  cache-read = 0.02;
                  output = 1.20;
                  tiers = [
                    {
                      min-input-tokens = 200001;
                      input = 0.40;
                      cache-read = 0.04;
                      output = 1.80;
                    }
                  ];
                }
                {
                  model = "gemini-2.5-pro";
                  input = 0.125;
                  cache-read = 0.0125;
                  output = 1.00;
                  tiers = [
                    {
                      min-input-tokens = 200001;
                      input = 0.25;
                      cache-read = 0.025;
                      output = 1.50;
                    }
                  ];
                }
                ## DeepSeek
                {
                  model = "deepseek-flash";
                  input = 0.44;
                  cache-read = 0.014;
                  output = 1.32;
                }
                {
                  model = "deepseek-v4-flash";
                  input = 0.44;
                  cache-read = 0.014;
                  output = 1.32;
                }
                {
                  model = "deepseek-chat";
                  input = 0.44;
                  cache-read = 0.014;
                  output = 1.32;
                }
                {
                  model = "deepseek-v4-pro";
                  input = 1.32;
                  cache-read = 0.042;
                  output = 3.96;
                }
                {
                  model = "deepseek-reasoner";
                  input = 1.32;
                  cache-read = 0.042;
                  output = 3.96;
                }
                ## Doubao Seed
                {
                  model = "doubao-seed-evolving*";
                  input = 0.88;
                  cache-read = 0.176;
                  output = 4.40;
                }
                {
                  model = "doubao-seed-2.1-pro";
                  input = 0.88;
                  cache-read = 0.176;
                  output = 4.40;
                }
                {
                  model = "doubao-seed-2-1-pro";
                  input = 0.88;
                  cache-read = 0.176;
                  output = 4.40;
                }
                {
                  model = "doubao-seed-2.1-turbo";
                  input = 0.44;
                  cache-read = 0.088;
                  output = 2.20;
                }
                {
                  model = "doubao-seed-2-1-turbo";
                  input = 0.44;
                  cache-read = 0.088;
                  output = 2.20;
                }
                {
                  model = "doubao-seed-2.1-lite";
                  input = 0.12;
                  cache-read = 0.024;
                  output = 0.40;
                }
                {
                  model = "doubao-seed-2-1-lite";
                  input = 0.12;
                  cache-read = 0.024;
                  output = 0.40;
                }
                ## Claude (patterns also cover dated and thinking variants)
                {
                  model = "claude-opus-5*";
                  input = 0.50;
                  cache-read = 0.05;
                  cache-write = 0.625;
                  output = 2.50;
                }
                {
                  model = "claude-opus-4-8*";
                  input = 0.50;
                  cache-read = 0.05;
                  cache-write = 0.625;
                  output = 2.50;
                }
                {
                  model = "claude-opus-4-7*";
                  input = 0.50;
                  cache-read = 0.05;
                  cache-write = 0.625;
                  output = 2.50;
                }
                {
                  model = "claude-opus-4-6*";
                  input = 0.50;
                  cache-read = 0.05;
                  cache-write = 0.625;
                  output = 2.50;
                }
                {
                  model = "claude-sonnet-5*";
                  input = 0.20;
                  cache-read = 0.02;
                  cache-write = 0.25;
                  output = 1.00;
                }
                {
                  model = "claude-sonnet-4-6*";
                  input = 0.30;
                  cache-read = 0.03;
                  cache-write = 0.375;
                  output = 1.50;
                }
                {
                  model = "claude-sonnet-4-5*";
                  input = 0.30;
                  cache-read = 0.03;
                  cache-write = 0.375;
                  output = 1.50;
                }
                {
                  model = "claude-haiku-5-5*";
                  input = 0.10;
                  cache-read = 0.01;
                  cache-write = 0.125;
                  output = 0.50;
                }
                {
                  model = "claude-haiku-4-5*";
                  input = 0.10;
                  cache-read = 0.01;
                  cache-write = 0.125;
                  output = 0.50;
                }
              ];
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
                models = [
                  {
                    name = "gemini-4-hydrogen";
                  }
                  {
                    name = "gemini-4-argon";
                  }
                  {
                    name = "gemini-4-carbon";
                  }
                  {
                    name = "gemini-3.8-flash";
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
                    api-key._secret = config.nixos.system.sops.secrets."cliproxyapi/deepseek".path;
                  }
                ];
                models = [
                  {
                    name = "deepseek-flash";
                  }
                ];
              }
              {
                name = "doubao";
                base-url = "https://ark.cn-beijing.volces.com/api/v3";
                priority = -1;
                keys = [
                  {
                    api-key._secret = config.nixos.system.sops.secrets."cliproxyapi/ark".path;
                  }
                ];
                models = [
                  {
                    name = "doubao-seed-evolving";
                  }
                ];
              }
              {
                name = "4router-gemini-aty";
                base-url = "https://4router.net/v1";
                priority = -2;
                keys = [
                  {
                    api-key._secret = config.nixos.system.sops.secrets."cliproxyapi/4router-gemini-aty".path;
                  }
                ];
                models = [
                  {
                    name = "gemini-4-hydrogen";
                  }
                  {
                    name = "gemini-4-argon";
                  }
                  {
                    name = "gemini-4-carbon";
                  }
                  {
                    name = "gemini-3.8-flash";
                  }
                ];
              }
              {
                name = "4router-gemini-api";
                base-url = "https://4router.net/v1";
                priority = -3;
                keys = [
                  {
                    api-key._secret = config.nixos.system.sops.secrets."cliproxyapi/4router-gemini-api".path;
                  }
                ];
                models = [
                  {
                    name = "gemini-4-hydrogen";
                  }
                  {
                    name = "gemini-4-argon";
                  }
                  {
                    name = "gemini-4-carbon";
                  }
                  {
                    name = "gemini-3.8-flash";
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
          nginx.https."internal.cliproxyapi.chn.moe" = {
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
          secrets =
            lib.genAttrs' (cliproxyapi.users ++ [ "infra" ]) (
              user: lib.nameValuePair "cliproxyapi/keys/${user}" { }
            )
            // {
              "cliproxyapi/management" = { };
              "cliproxyapi/gemini" = { };
              "cliproxyapi/deepseek" = { };
              "cliproxyapi/ark" = { };
              "cliproxyapi/4router-gemini-api" = { };
              "cliproxyapi/4router-gemini-aty" = { };
            };
          templates."cliproxyapi/postgres-dsn".content = "postgres://cliproxyapi:${
            config.nixos.system.sops.placeholder."postgresql/cliproxyapi"
          }@127.0.0.1:5432/cliproxyapi?sslmode=disable";
        };
      };
    };
}
