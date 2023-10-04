inputs:
{
  options.nixos.services.nextcloud = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.str; default = "nextcloud.chn.moe"; };
  };
  config =
    let
      inherit (inputs.config.nixos.services) nextcloud;
      inherit (inputs.localLib) attrsToList;
      inherit (inputs.lib) mkIf mkMerge;
      inherit (builtins) map listToAttrs toString replaceStrings filter toJSON;
    in mkIf nextcloud.enable
    {
      services.nextcloud =
      {
        enable = true;
        hostName = nextcloud.hostname;
        appstoreEnable = false;
        https = true;
        package = inputs.pkgs.nextcloud27;
        maxUploadSize = "10G";
        config =
        {
          dbtype = "pgsql";
          dbpassFile = inputs.config.sops.secrets."nextcloud/postgresql".path;
          dbport = 5432;
          adminuser = "admin";
          adminpassFile = inputs.config.sops.secrets."nextcloud/admin".path;
          overwriteProtocol = "https";
          defaultPhoneRegion = "CN";
        };
        configureRedis = true;
        extraOptions =
        {
          mail_domain = "chn.moe";
          mail_from_address = "nextcloud";
          mail_smtphost = "mail.chn.moe";
          mail_smtpport = 465;
          mail_smtpsecure = "ssl";
          mail_smtpauth = true;
          mail_smtpname = "bot@chn.moe";
        };
        secretFile = inputs.config.sops.templates."nextcloud/secret".path;
      };
      nixos.services =
      {
        postgresql = { enable = true; instances.nextcloud = {}; };
        redis.instances.nextcloud.port = 3499;
      };
      sops =
      {
        templates."nextcloud/secret" =
        {
          content = toJSON
          {
            redis.password = inputs.config.sops.placeholder."redis/nextcloud";
            mail_smtppassword = inputs.config.sops.placeholder."mail/bot";
          };
          owner = inputs.config.users.users.nextcloud.name;
        };
        secrets =
        {
          "nextcloud/postgresql" = { key = "postgresql/nextcloud"; owner = inputs.config.users.users.nextcloud.name; };
          "nextcloud/admin".owner = inputs.config.users.users.nextcloud.name;
        };
      };
    };
}
