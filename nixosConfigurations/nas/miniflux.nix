{ config, ... }:
let
  port = 8280;
in
{
  services.miniflux = {
    enable = true;
    createDatabaseLocally = false;
    adminCredentialsFile = config.nixos.system.sops.templates."miniflux.env".path;
    config = {
      LISTEN_ADDR = "127.0.0.1:${toString port}";
      BASE_URL = "https://miniflux.chn.moe";
      CREATE_ADMIN = 1;
      RUN_MIGRATIONS = 1;
      ADMIN_USERNAME = "chn";
    };
  };

  # Make sure systemd service miniflux picks up DATABASE_URL and admin credentials from the template
  # and wait for postgresql to be ready
  systemd.services.miniflux = {
    after = [ "postgresql.service" ];
    requires = [ "postgresql.service" ];
  };

  nixos = {
    services = {
      postgresql.instances.miniflux = { };
      nginx.https."miniflux.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:${toString port}";
    };

    system.sops = {
      templates."miniflux.env" = {
        content =
          let
            inherit (config.nixos.system.sops) placeholder;
          in
          ''
            DATABASE_URL="user=miniflux password=${
              placeholder."postgresql/miniflux"
            } dbname=miniflux sslmode=disable"
            ADMIN_PASSWORD=${placeholder."miniflux/password"}
          '';
      };
      secrets."miniflux/password" = { };
    };
  };
}
