{
  config,
  pkgs,
  lib,
  ...
}:
{
  config = {
    services = {
      grafana = {
        enable = true;
        declarativePlugins = with pkgs.grafanaPlugins; [ ];
        settings = {
          users = {
            verify_email_enabled = true;
            default_language = "zh-CN";
            allow_sign_up = true;
          };
          smtp = {
            enabled = true;
            host = "mail.chn.moe";
            user = "bot@chn.moe";
            password = "$__file{${config.nixos.system.sops.secrets."grafana/mail".path}}";
            from_address = "bot@chn.moe";
            ehlo_identity = "grafana.chn.moe";
            startTLS_policy = "MandatoryStartTLS";
          };
          server = {
            root_url = "https://grafana.chn.moe";
            http_port = 3001;
            enable_gzip = true;
          };
          security = {
            secret_key = "$__file{${config.nixos.system.sops.secrets."grafana/secret".path}}";
            admin_user = "chn";
            admin_password = "$__file{${config.nixos.system.sops.secrets."grafana/chn".path}}";
            admin_email = "chn@chn.moe";
          };
          database = {
            type = "postgres";
            host = "127.0.0.1:5432";
            user = "grafana";
            password = "$__file{${config.nixos.system.sops.secrets."grafana/db".path}}";
          };
        };
        provision = {
          enable = true;
          datasources.settings = {
            prune = true;
            datasources = [
              {
                name = "Prometheus";
                type = "prometheus";
                access = "proxy";
                url = "http://127.0.0.1:${toString config.services.prometheus.port}";
                editable = false;
              }
            ];
          };
          dashboards.settings.providers = [
            {
              name = "dashboards";
              options.path = pkgs.runCommand "grafana-dashboards" { } ''
                mkdir -p $out
                cp ${
                  pkgs.fetchurl {
                    url = "https://grafana.com/api/dashboards/1860/revisions/37/download";
                    sha256 = "0qza4j8lywrj08bqbww52dgh2p2b9rkhq5p313g72i57lrlkacfl";
                  }
                } $out/node-exporter.json
                cp ${
                  pkgs.fetchurl {
                    url = "https://grafana.com/api/dashboards/24237/revisions/1/download";
                    sha256 = "0zxwbcvkccbg31xk5gx2gszkr4ifbamnk4n90dsrsrjj9ykar7il";
                  }
                } $out/nginx-vts.json
                cp ${
                  pkgs.fetchurl {
                    url = "https://grafana.com/api/dashboards/11545/revisions/2/download";
                    sha256 = "0im7qy4piqwwjyww8h7gf4qmaba5ikzv5rd3gx8dqfi2786bppmc";
                  }
                } $out/v2ray-exporter.json
              '';
            }
          ];
        };
      };
      prometheus = {
        enable = true;
        port = 9091;
        scrapeConfigs = [
          {
            job_name = "node";
            scrape_interval = "1m";
            static_configs = [
              {
                targets =
                  let
                    port = toString config.services.prometheus.exporters.node.port;
                  in
                  lib.concatLists [
                    (lib.map (h: "${h}.ts.chn.moe:${port}") [
                      "nas"
                      "pc"
                      "srv1-node0"
                      "srv1-node1"
                      "srv1-node2"
                      "srv2-node0"
                      "srv2-node1"
                      "srv2-node2"
                    ])
                    (lib.map (h: "tinc0.${h}.chn.moe:${port}") [
                      "vps4"
                      "vps6"
                      "vps10"
                    ])
                  ];
              }
            ];
          }
          {
            job_name = "nginx";
            scrape_interval = "1m";
            static_configs = [
              {
                targets =
                  let
                    port = "9113"; # nginx exporter port
                  in
                  lib.concatLists [
                    (lib.map (h: "${h}.ts.chn.moe:${port}") [
                      "nas"
                    ])
                    (lib.map (h: "tinc0.${h}.chn.moe:${port}") [
                      "vps4"
                      "vps6"
                      "vps10"
                    ])
                  ];
              }
            ];
          }
          {
            job_name = "xray";
            scrape_interval = "1m";
            static_configs = [
              {
                targets =
                  let
                    port = toString config.services.prometheus.exporters.v2ray.port;
                  in
                  lib.map (h: "tinc0.${h}.chn.moe:${port}") [
                    "vps4"
                    "vps6"
                    "vps10"
                  ];
              }
            ];
          }
        ];
        extraFlags = [ "--storage.tsdb.max-block-chunk-segment-size=16MB" ];
      };
    };
    nixos = {
      services = {
        nginx.https."grafana.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:3001";
        postgresql.instances.grafana = { };
      };
      system.sops.secrets =
        let
          owner = config.systemd.services.grafana.serviceConfig.User;
        in
        {
          "grafana/mail" = {
            owner = owner;
            key = "mail/bot";
          };
          "grafana/secret".owner = owner;
          "grafana/chn".owner = owner;
          "grafana/db" = {
            owner = owner;
            key = "postgresql/grafana";
          };
          "mail/bot" = { };
        };
    };
    environment.persistence."/nix/nodatacow".directories = [
      {
        directory = "/var/lib/prometheus2";
        user = "prometheus";
        group = "prometheus";
        mode = "0700";
      }
    ];
  };
}
