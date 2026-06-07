inputs: {
  options.nixos.services.vaultwarden =
    let
      inherit (inputs.lib) mkOption types;
    in
    mkOption {
      type = types.nullOr (
        types.submodule {
          options = {
            hostname = mkOption {
              type = types.nonEmptyStr;
              default = "vaultwarden.chn.moe";
            };
          };
        }
      );
      default = null;
    };
  config =
    let
      inherit (inputs.config.nixos.services) vaultwarden;
    in
    inputs.lib.mkIf (vaultwarden != null) {
      services.vaultwarden = {
        enable = true;
        dbBackend = "postgresql";
        config = {
          WEB_VAULT_ENABLED = true;
          SIGNUPS_VERIFY = true;
          DOMAIN = "https://${vaultwarden.hostname}";
          SMTP_HOST = "mail.chn.moe";
          SMTP_FROM = "bot@chn.moe";
          SMTP_FROM_NAME = "vaultwarden";
          SMTP_SECURITY = "force_tls";
          SMTP_USERNAME = "bot@chn.moe";
        };
        environmentFile = inputs.config.nixos.system.sops.templates."vaultwarden.env".path;
      };
      nixos = {
        system.sops = {
          templates."vaultwarden.env" =
            let
              inherit (inputs.config.nixos.system.sops) placeholder;
            in
            {
              owner = "vaultwarden";
              group = "vaultwarden";
              content = ''
                DATABASE_URL=postgresql://vaultwarden:${placeholder."postgresql/vaultwarden"}@localhost/vaultwarden
                ADMIN_TOKEN=${placeholder."vaultwarden/admin_token"}
                SMTP_PASSWORD=${placeholder."mail/bot"}
              '';
            };
          secrets = {
            "vaultwarden/admin_token" = { };
            "mail/bot" = { };
          };
        };
        services = {
          postgresql.instances.vaultwarden = { };
          nginx.https.${vaultwarden.hostname}.location."/".proxy.upstream = "http://127.0.0.1:8000";
        };
      };
      systemd.services.vaultwarden.after = [ "postgresql.service" ];
    };
}
