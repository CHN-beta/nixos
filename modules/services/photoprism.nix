inputs:
{
  options.nixos.services.photoprism = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.nonEmptyStr; default = "photoprism.chn.moe"; };
    port = mkOption { type = types.ints.unsigned; default = 2342; };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos.services) photoprism;
    in mkIf photoprism.enable
    {
      services.photoprism =
      {
        enable = true;
        originalsPath = inputs.config.services.photoprism.storagePath + "/originals";
        settings =
        {
          PHOTOPRISM_SITE_URL = "https://${photoprism.hostname}";
          PHOTOPRISM_HTTP_PORT = "${toString photoprism.port}";
          PHOTOPRISM_DISABLE_TLS = "true";
          PHOTOPRISM_DETECT_NSFW = "true";
          PHOTOPRISM_UPLOAD_NSFW = "true";
          PHOTOPRISM_DATABASE_DRIVER = "mysql";
          PHOTOPRISM_DATABASE_SERVER = "127.0.0.1:3306";
        };
      };
      systemd.services.photoprism =
      {
        after = [ "mariadb.service" ];
        requires = [ "mariadb.service" ];
        serviceConfig.EnvironmentFile = inputs.config.sops.templates."photoprism/env".path; 
      };
      sops =
      {
        templates."photoprism/env".content = let placeholder = inputs.config.sops.placeholder; in
        ''
          PHOTOPRISM_ADMIN_PASSWORD=${placeholder."photoprism/adminPassword"}
          PHOTOPRISM_DATABASE_PASSWORD=${placeholder."mariadb/photoprism"}
        '';
        secrets."photoprism/adminPassword" = {}; 
      };
      nixos.services =
      {
        mariadb = { enable = true; instances.photoprism = {}; };
        nginx =
        {
          enable = true;
          https.${photoprism.hostname}.location."/".proxy =
            { upstream = "http://127.0.0.1:${toString photoprism.port}"; websocket = true; };
        };
      };
    };
}
