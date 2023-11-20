inputs:
{
  options.nixos.services.grafana = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.str; default = "grafana.chn.moe"; };
  };
  config =
    let
      inherit (inputs.config.nixos.services) grafana;
      inherit (inputs.lib) mkIf;
    in mkIf grafana.enable
    {
      services.grafana =
      {
        enable = true;
        declarativePlugins = with inputs.pkgs.grafanaPlugins; [];
        settings =
        {
          users = { verify_email_enabled = true; default_language = "zh-CN"; allow_sign_up = true; };
          smtp =
          {
            enabled = true;
            host = "mail.chn.moe";
            user = "bot@chn.moe";
            password = "$__file{${inputs.config.sops.secrets."grafana/mail".path}}";
            from_address = "bot@chn.moe";
            ehlo_identity = grafana.hostname;
            startTLS_policy = "MandatoryStartTLS";
          };
          server = { root_url = "https://${grafana.hostname}"; http_port = 3001; enable_gzip = true; };
          security =
          {
            secret_key = "$__file{${inputs.config.sops.secrets."grafana/secret".path}}";
            admin_user = "chn";
            admin_password = "$__file{${inputs.config.sops.secrets."grafana/chn".path}}";
            admin_email = "chn@chn.moe";
          };
          database =
          {
            type = "postgres";
            host = "127.0.0.1:5432";
            user = "grafana";
            password = "$__file{${inputs.config.sops.secrets."grafana/db".path}}";
          };
        };
      };
      nixos.services =
      {
        nginx =
        {
          enable = true;
          https."${grafana.hostname}".location."/".proxy =
            { upstream = "http://127.0.0.1:3001"; websocket = true; };
        };
        postgresql.instances.grafana = {};
      };
      sops.secrets = let owner = inputs.config.systemd.services.grafana.serviceConfig.User; in
      {
        "grafana/mail" = { owner = owner; key = "mail/bot"; };
        "grafana/secret".owner = owner;
        "grafana/chn".owner = owner;
        "grafana/db" = { owner = owner; key = "postgresql/grafana"; };
        "mail/bot" = {};
      };
    };
}
