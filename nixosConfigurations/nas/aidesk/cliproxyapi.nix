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
              antigravity = { };
            };
          };
          access.api-keys = lib.map (user: {
            key._secret = config.nixos.system.sops.secrets."cliproxyapi/keys/${user}".path;
            name = user;
            models =
              if
                lib.elem user [
                  "chn"
                  "infra"
                ]
              then
                [ "*" ]
              else
                [
                  # Gemini
                  "gemini-3.8-flash"
                  "gemini-4-argon"
                  "gemini-4-carbon"
                  "gemini-4-hydrogen"
                  # Deepseek
                  "deepseek-flash"
                  "deepseek-v4-pro"
                  # Doubao
                  "doubao-seed-evolving"
                  # Anthropic
                  "claude-fable-5-2"
                  "claude-haiku-5-5"
                  "claude-sonnet-5-5"
                  "claude-opus-5-5"
                  # OpenAI
                  "gpt-6.2-astra"
                  "gpt-6.2-sol"
                ];
          }) (cliproxyapi.users ++ [ "infra" ]);
          observability = {
            logs = {
              debug = false;
              logging-to-file = false;
              logs-max-total-size-mb = 1024;
              error-logs-max-files = 10;
              request-log = true;
            };
            usage = {
              usage-statistics-enabled = true;
              redis-usage-queue-retention-seconds = 60;
              postgres-dsn._secret = config.nixos.system.sops.templates."cliproxyapi/postgres-dsn".path;
              model-pricing = [
                ## Gemini
                {
                  model = "gemini-3.8-flash";
                  input = 2.25; # 0.3375
                  cache-read = 0.225; # 0.03375
                  output = 11.25; # 1.6875
                }
                {
                  model = "gemini-4-argon";
                  input = 6; # 0.9
                  cache-read = 0.3; # 0.045
                  output = 30; # 4.5
                }
                {
                  model = "gemini-4-carbon";
                  input = 6; # 0.9
                  cache-read = 0.3; # 0.045
                  output = 30; # 4.5
                }
                {
                  model = "gemini-4-hydrogen";
                  input = 4.5; # 0.675
                  cache-read = 0.225; # 0.03375
                  output = 22.5; # 3.375
                }
                ## DeepSeek
                {
                  model = "deepseek-flash";
                  input = 3;
                  cache-read = 0.06;
                  output = 12;
                }
                {
                  model = "deepseek-v4-pro";
                  input = 13.5;
                  cache-read = 0.45;
                  output = 40.5;
                }
                ## Doubao
                {
                  model = "doubao-seed-evolving";
                  input = 9;
                  cache-read = 1.8;
                  output = 45;
                }
                ## Claude
                {
                  model = "claude-fable-5-2";
                  input = 21.6;
                  cache-read = 0.54;
                  cache-write = 27;
                  output = 108;
                }
                {
                  model = "claude-haiku-5-5";
                  input = 0.27;
                  cache-read = 0.027;
                  cache-write = 0.3375;
                  output = 1.35;
                  tiers = [
                    {
                      min-input-tokens = 100001;
                      input = 1.35;
                      cache-read = 0.135;
                      cache-write = 1.6875;
                      output = 6.75;
                    }
                  ];
                }
                {
                  model = "claude-sonnet-5-5";
                  input = 5.4;
                  cache-read = 0.27;
                  cache-write = 6.75;
                  output = 27;
                }
                {
                  model = "claude-opus-5-5";
                  input = 10.8;
                  cache-read = 0.54;
                  cache-write = 13.5;
                  output = 54;
                }
                # OpenAI
                {
                  model = "gpt-6.2-astra";
                  input = 6;
                  cache-read = 0.3;
                  cache-write = 7.5;
                  output = 30;
                }
                {
                  model = "gpt-6.2-sol";
                  input = 1.5;
                  cache-read = 0.075;
                  cache-write = 1.875;
                  output = 7.5;
                }
              ];
            };
            pprof = {
              enable = false;
              addr = "127.0.0.1:8316";
            };
          };
          requests = {
            proxy-url = "socks5://127.0.0.1:10886";
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
                proxy-url = "direct";
                keys = [
                  {
                    api-key._secret = config.nixos.system.sops.secrets."cliproxyapi/deepseek".path;
                  }
                ];
                models = [
                  {
                    name = "deepseek-flash";
                  }
                  {
                    name = "deepseek-V4-pro";
                    alias = "deepseek-v4-pro";
                  }
                ];
              }
              {
                name = "doubao";
                base-url = "https://ark.cn-beijing.volces.com/api/v3";
                priority = -1;
                proxy-url = "direct";
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
                name = "4router-gemini-agy";
                base-url = "https://4router.net/v1";
                priority = -2;
                keys = [
                  {
                    api-key._secret = config.nixos.system.sops.secrets."cliproxyapi/4router-gemini-agy".path;
                  }
                ];
                models = [
                  {
                    name = "gemini-4-hydrogen";
                    alias = "gemini-4-hydrogen-agy";
                  }
                  {
                    name = "gemini-4-argon";
                    alias = "gemini-4-argon-agy";
                  }
                  {
                    name = "gemini-4-carbon";
                    alias = "gemini-4-carbon-agy";
                  }
                  {
                    name = "gemini-3.8-flash";
                    alias = "gemini-3.8-flash-agy";
                  }
                ];
              }
              {
                name = "4router-openai";
                base-url = "https://4router.net/v1";
                priority = -2;
                keys = [
                  {
                    api-key._secret = config.nixos.system.sops.secrets."cliproxyapi/4router-openai".path;
                  }
                ];
                models = [
                  {
                    name = "gpt-6.2-astra";
                  }
                  {
                    name = "gpt-6.2-sol";
                  }
                ];
              }
              {
                name = "4router-anthropic";
                base-url = "https://4router.net/v1";
                priority = -2;
                keys = [
                  {
                    api-key._secret = config.nixos.system.sops.secrets."cliproxyapi/4router-anthropic".path;
                  }
                ];
                models = [
                  {
                    name = "claude-fable-5-2";
                  }
                  {
                    name = "claude-haiku-5-5";
                  }
                  {
                    name = "claude-opus-5-5";
                  }
                  {
                    name = "claude-sonnet-5-5";
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
              "cliproxyapi/4router-gemini-agy" = { };
              "cliproxyapi/4router-openai" = { };
              "cliproxyapi/4router-anthropic" = { };
            };
          templates."cliproxyapi/postgres-dsn".content = "postgres://cliproxyapi:${
            config.nixos.system.sops.placeholder."postgresql/cliproxyapi"
          }@127.0.0.1:5432/cliproxyapi?sslmode=disable";
        };
      };
    };
}
