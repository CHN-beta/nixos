inputs: {
  options.nixos.services.huginn =
    let
      inherit (inputs.lib) mkOption types;
    in
    mkOption {
      type = types.nullOr (
        types.submodule {
          options = {
            hostname = mkOption {
              type = types.str;
              default = "huginn.chn.moe";
            };
          };
        }
      );
      default = null;
    };
  config =
    let
      inherit (inputs.config.nixos.services) huginn;
    in
    inputs.lib.mkIf (huginn != null) {
      virtualisation.oci-containers.containers.huginn = {
        image = "ghcr.io/huginn/huginn:latest";
        imageFile = inputs.self.src.huginn;
        ports = [ "127.0.0.1:3000:3000/tcp" ];
        environmentFiles = [ inputs.config.nixos.system.sops.templates."huginn/env".path ];
      };
      nixos = {
        services = {
          nginx.https.${huginn.hostname}.location."/".proxy.upstream = "http://127.0.0.1:3000";
          mariadb.instances.huginn = { };
          podman = { };
        };
        system.sops = {
          templates."huginn/env".content =
            let
              inherit (inputs.config.nixos.system.sops) placeholder;
            in
            ''
              MYSQL_PORT_3306_TCP_ADDR=host.containers.internal
              HUGINN_DATABASE_NAME=huginn
              HUGINN_DATABASE_USERNAME=huginn
              HUGINN_DATABASE_PASSWORD=${placeholder."mariadb/huginn"}
              DOMAIN=${huginn.hostname}
              RAILS_ENV=production
              FORCE_SSL=true
              INVITATION_CODE=${placeholder."huginn/invitationCode"}
              SMTP_DOMAIN=mail.chn.moe
              SMTP_USER_NAME=bot@chn.moe
              SMTP_PASSWORD="${placeholder."mail/bot"}"
              SMTP_SERVER=mail.chn.moe
              SMTP_SSL=true
              EMAIL_FROM_ADDRESS=bot@chn.moe
              TIMEZONE=Beijing
              DO_NOT_CREATE_DATABASE=true
            '';
          secrets = {
            "huginn/invitationCode" = { };
            "mail/bot" = { };
          };
        };
      };
    };
}
