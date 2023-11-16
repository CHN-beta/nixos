inputs:
{
  options.nixos.services.freshrss = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.str; default = "freshrss.chn.moe"; };
  };
  config =
    let
      inherit (inputs.config.nixos.services) freshrss;
      inherit (inputs.lib) mkIf;
    in mkIf freshrss.enable
    {
      services.freshrss =
      {
        enable = true;
        baseUrl = "https://${freshrss.hostname}";
        defaultUser = "chn";
        passwordFile = inputs.config.sops.secrets."freshrss/chn".path;
        database = { type = "mysql"; passFile = inputs.config.sops.secrets."freshrss/db".path; };
        virtualHost = null;
      };
      sops.secrets =
      {
        "freshrss/chn".owner = inputs.config.users.users.freshrss.name;
        "freshrss/db" = { owner = inputs.config.users.users.freshrss.name; key = "mariadb/freshrss"; };
      };
      systemd.services.freshrss-config.after = [ "mysql.service" ];
      nixos.services =
      {
        mariadb = { enable = true; instances.freshrss = {}; };
        nginx.https.${freshrss.hostname} =
        {
          location =
          {
            "/".static =
            {
              root = "${inputs.pkgs.freshrss}/p";
              index = [ "index.php" ];
              tryFiles = [ "$uri" "$uri/" "$uri/index.php" ];
            };
            "~ ^.+?\.php(/.*)?$".php =
            {
              root = "${inputs.pkgs.freshrss}/p";
              fastcgiPass =
                "unix:${inputs.config.services.phpfpm.pools.${inputs.config.services.freshrss.pool}.socket}";
            };
          };
        };
      };
    };
}
