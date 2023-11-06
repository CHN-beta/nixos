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
        database =
        {
          type = "mysql";
          passFile = inputs.config.sops.secrets."freshrss/mysql".path;
        };
      };
      sops.secrets =
      {
        "freshrss/chn".owner = inputs.config.users.users.freshrss.name;
        "freshrss/db" =
        {
          owner = inputs.config.users.users.freshrss.name;
          key = "mariadb/freshrss";
        };
      };
      nixos.mariadb = { enable = true; instances.freshrss = {}; };
      systemd.services.freshrss-config.after = [ "mysql.service" ];
    };
}
