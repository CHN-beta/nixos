{ config, pkgs, ... }: {
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
                url = "http://localhost:9090";
                editable = false;
              }
            ];
          };
        };
      };
      prometheus = {
        enable = true;
        exporters = {
          node = {
            enable = true;
            enabledCollectors = [ "systemd" ];
          };
        };
        scrapeConfigs = [
          {
            job_name = "lapetus";
            static_configs = [
              { targets = [ "127.0.0.1:${toString config.services.prometheus.exporters.node.port}" ]; }
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
