inputs:
{
  options.nixos.services.vaultwarden = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    autoStart = mkOption { type = types.bool; default = true; };
    port = mkOption { type = types.ints.unsigned; default = 8000; };
    websocketPort = mkOption { type = types.ints.unsigned; default = 3012; };
    hostname = mkOption { type = types.str; default = "vaultwarden.chn.moe"; };
  };
  config =
    let
      inherit (inputs.config.nixos.services) vaultwarden;
      inherit (builtins) listToAttrs toString;
      inherit (inputs.lib) mkIf;
    in mkIf vaultwarden.enable
    {
      services.vaultwarden =
      {
        enable = true;
        dbBackend = "postgresql";
        config =
        {
          DATA_FOLDER = "/var/lib/vaultwarden";
          WEB_VAULT_ENABLED = true;
          WEBSOCKET_ENABLED = true;
          ROCKET_PORT = vaultwarden.port;
          WEBSOCKET_PORT = toString vaultwarden.websocketPort;
          SIGNUPS_VERIFY = true;
          DOMAIN = "https://${vaultwarden.hostname}";
          SMTP_HOST = "mail.chn.moe";
          SMTP_FROM = "bot@chn.moe";
          SMTP_FROM_NAME = "vaultwarden";
          SMTP_SECURITY = "force_tls";
          SMTP_USERNAME = "bot@chn.moe";
        };
        environmentFile = inputs.config.sops.templates."vaultwarden.env".path;
      };
      sops =
      {
        templates."vaultwarden.env" =
          let
            serviceConfig = inputs.config.systemd.services.vaultwarden.serviceConfig;
            placeholder = inputs.config.sops.placeholder;
          in
          {
            owner = serviceConfig.User;
            group = serviceConfig.Group;
            content =
            ''
              DATABASE_URL=postgresql://vaultwarden:${placeholder."postgresql/vaultwarden"}@localhost/vaultwarden
              ADMIN_TOKEN=${placeholder."vaultwarden/admin_token"}
              SMTP_PASSWORD=${placeholder."mail/bot"}
            '';
          };
        secrets = listToAttrs (map
          (secret: { name = secret; value = {}; })
          [ "vaultwarden/admin_token" "mail/bot" ]);
      };
      systemd.services.vaultwarden =
      {
        enable = vaultwarden.autoStart;
        after = [ "postgresql.service" ];
      };
      nixos.services =
      {
        postgresql = { enable = true; instances.vaultwarden = {}; };
        nginx =
        {
          enable = true;
          https.${vaultwarden.hostname} =
          {
            global.rewriteHttps = true;
            listen.main.proxyProtocol = true;
            location = listToAttrs
            (
              (map
                (location:
                {
                  name = location;
                  value.proxy =
                  {
                    upstream = "http://127.0.0.1:${toString vaultwarden.port}";
                    setHeaders = { Host = vaultwarden.hostname; Connection = ""; };
                  };
                })
                [ "/" "/notifications/hub/negotiate" ])
              ++ (map
                (location:
                {
                  name = location;
                  value.proxy =
                  {
                    upstream = "http://127.0.0.1:${toString vaultwarden.websocketPort}";
                    websocket = true;
                    setHeaders.Host = vaultwarden.hostname;
                  };
                })
                [ "/notifications/hub" ])
            );
          };
        };
      };
    };
}
