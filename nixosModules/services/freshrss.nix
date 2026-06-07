inputs: {
  options.nixos.services.freshrss =
    let
      inherit (inputs.lib) mkOption types;
    in
    mkOption {
      type = types.nullOr (
        types.submodule {
          options = {
            hostname = mkOption {
              type = types.str;
              default = "freshrss.chn.moe";
            };
          };
        }
      );
      default = null;
    };
  config =
    let
      inherit (inputs.config.nixos.services) freshrss;
    in
    inputs.lib.mkIf (freshrss != null) {
      services.freshrss = {
        enable = true;
        baseUrl = "https://${freshrss.hostname}";
        defaultUser = "chn";
        passwordFile = inputs.config.nixos.system.sops.secrets."freshrss/chn".path;
        database = {
          type = "mysql";
          passFile = inputs.config.nixos.system.sops.secrets."freshrss/db".path;
        };
      };
      systemd.services.freshrss-config.after = [ "mysql.service" ];
      nixos = {
        services = {
          mariadb.instances.freshrss = { };
          nginx.https.${freshrss.hostname}.global.configName = "freshrss";
        };
        system.sops.secrets = {
          "freshrss/chn".owner = inputs.config.users.users.freshrss.name;
          "freshrss/db" = {
            owner = inputs.config.users.users.freshrss.name;
            key = "mariadb/freshrss";
          };
        };
      };
    };
}
