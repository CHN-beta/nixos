inputs:
{
  options.nixos.services.nextcloud = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      hostname = mkOption { type = types.nonEmptyStr; default = "nextcloud.chn.moe"; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) nextcloud; in inputs.lib.mkIf (nextcloud != null)
  {
    services.nextcloud =
    {
      enable = true;
      hostName = nextcloud.hostname;
      appstoreEnable = false;
      https = true;
      package = inputs.pkgs.nextcloud30;
      maxUploadSize = "10G";
      config =
      {
        dbtype = "pgsql";
        dbpassFile = inputs.config.sops.secrets."nextcloud/postgresql".path;
        adminuser = "admin";
        adminpassFile = inputs.config.sops.secrets."nextcloud/admin".path;
      };
      configureRedis = true;
      settings =
      {
        mail_domain = "chn.moe";
        mail_from_address = "bot";
        mail_smtphost = "mail.chn.moe";
        mail_smtpport = 465;
        mail_smtpsecure = "ssl";
        mail_smtpauth = true;
        mail_smtpname = "bot@chn.moe";
        updatechecker = false;
        overwriteprotocol = "https";
        default_phone_region = "CN";
      };
      secretFile = inputs.config.sops.templates."nextcloud/secret".path;
      extraApps =
        let
          version = inputs.lib.versions.major inputs.config.services.nextcloud.package.version;
          info = builtins.fromJSON (builtins.readFile "${inputs.topInputs.nc4nix}/${version}.json");
          getInfo = package:
          {
            inherit (info.${package}) hash url description homepage;
            appName = package;
            appVersion = info.${package}.version;
            license =
              let
                licenses = { agpl = "agpl3Only"; };
                originalLincense = builtins.head info.${package}.licenses;
              in licenses.${originalLincense} or originalLincense;
          };
        in builtins.listToAttrs (builtins.map
          (package: { name = package; value = inputs.pkgs.fetchNextcloudApp (getInfo package); })
          [ "maps" "phonetrack" "twofactor_webauthn" "calendar" ]);
    };
    nixos.services =
    {
      postgresql.instances.nextcloud = {};
      redis.instances.nextcloud.port = 3499;
      nginx = { enable = true; https.${nextcloud.hostname}.global.configName = nextcloud.hostname; };
    };
    sops =
    {
      templates."nextcloud/secret" =
      {
        content = builtins.toJSON
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
    systemd.services.nextcloud-setup = rec { requires = [ "postgresql.service" ]; after = requires; };
  };
}
