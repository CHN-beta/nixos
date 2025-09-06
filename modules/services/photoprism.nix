inputs:
{
  options.nixos.services.photoprism = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) photoprism; in inputs.lib.mkIf (photoprism != null)
  {
    services.photoprism =
    {
      enable = true;
      originalsPath = inputs.config.services.photoprism.storagePath + "/originals";
      settings =
      {
        PHOTOPRISM_SITE_URL = "https://photoprism.chn.moe";
        PHOTOPRISM_HTTP_PORT = "2342";
        PHOTOPRISM_DISABLE_TLS = "true";
        PHOTOPRISM_DETECT_NSFW = "true";
        PHOTOPRISM_UPLOAD_NSFW = "true";
        PHOTOPRISM_DATABASE_DRIVER = "mysql";
        PHOTOPRISM_DATABASE_SERVER = "127.0.0.1:3306";
      };
    };
    systemd.services.photoprism =
    {
      after = [ "mysql.service" ];
      requires = [ "mysql.service" ];
      serviceConfig.EnvironmentFile = inputs.config.nixos.system.sops.templates."photoprism/env".path; 
    };
    nixos =
    {
      system.sops =
      {
        templates."photoprism/env".content = let inherit (inputs.config.nixos.system.sops) placeholder; in
        ''
          PHOTOPRISM_ADMIN_PASSWORD=${placeholder."photoprism/adminPassword"}
          PHOTOPRISM_DATABASE_PASSWORD=${placeholder."mariadb/photoprism"}
        '';
        secrets."photoprism/adminPassword" = {}; 
      };
      services =
      {
        mariadb.instances.photoprism = {};
        nginx.https."photoprism.chn.moe".location."/".proxy = { upstream = "http://127.0.0.1:2342"; websocket = true; };
      };
    };
  };
}
