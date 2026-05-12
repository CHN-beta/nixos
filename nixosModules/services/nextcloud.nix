{ lib, config, pkgs, flakeInputs, ... }:
{
  options.nixos.services.nextcloud = lib.mkOption
  {
    type = lib.types.nullOr (lib.types.submodule { options =
    {
      hostname = lib.mkOption { type = lib.types.nonEmptyStr; default = "nextcloud.chn.moe"; };
    };});
    default = null;
  };
  config = let inherit (config.nixos.services) nextcloud; in lib.mkIf (nextcloud != null)
  {
    services.nextcloud =
    {
      enable = true;
      hostName = nextcloud.hostname;
      appstoreEnable = false;
      https = true;
      package = pkgs.nextcloud32;
      maxUploadSize = "10G";
      config =
      {
        dbtype = "pgsql";
        dbpassFile = config.nixos.system.sops.secrets."nextcloud/postgresql".path;
        adminuser = "admin";
        adminpassFile = config.nixos.system.sops.secrets."nextcloud/admin".path;
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
      secretFile = config.nixos.system.sops.templates."nextcloud/secret".path;
      extraApps =
        let
          version = lib.versions.major config.services.nextcloud.package.version;
          info = builtins.fromJSON (builtins.readFile "${flakeInputs.nc4nix}/${version}.json");
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
          (package: { name = package; value = pkgs.fetchNextcloudApp (getInfo package); })
          [ "phonetrack" "twofactor_webauthn" "calendar" ]);
    };
    nixos =
    {
      system.sops =
      {
        templates."nextcloud/secret" =
        {
          content = builtins.toJSON
          {
            redis.password = config.nixos.system.sops.placeholder."redis/nextcloud";
            mail_smtppassword = config.nixos.system.sops.placeholder."mail/bot";
          };
          owner = config.users.users.nextcloud.name;
        };
        secrets =
        {
          "nextcloud/postgresql" = { key = "postgresql/nextcloud"; owner = config.users.users.nextcloud.name; };
          "nextcloud/admin".owner = config.users.users.nextcloud.name;
        };
      };
      services =
      {
        postgresql.instances.nextcloud = {};
        redis.instances.nextcloud.port = 3499;
        nginx.https.${nextcloud.hostname}.global.configName = nextcloud.hostname;
      };
    };
    systemd.services.nextcloud-setup = rec { requires = [ "postgresql.service" ]; after = requires; };
  };
}
