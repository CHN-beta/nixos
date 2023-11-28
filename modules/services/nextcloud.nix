inputs:
{
  options.nixos.services.nextcloud = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.nonEmptyStr; default = "nextcloud.chn.moe"; };
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
          mail_from_address = "bot";
          mail_smtphost = "mail.chn.moe";
          mail_smtpport = 465;
          mail_smtpsecure = "ssl";
          mail_smtpauth = true;
          mail_smtpname = "bot@chn.moe";
          updatechecker = false;
        };
        secretFile = inputs.config.sops.templates."nextcloud/secret".path;
        extraApps =
          let
            githubRelease = repo: file: "https://github.com/${repo}/releases/download/${file}";
          in
          {
            maps = inputs.pkgs.fetchNextcloudApp
            {
              url = githubRelease "nextcloud/maps" "v1.1.1/maps-1.1.1.tar.gz";
              sha256 = "1rcmqnm5364h5gaq1yy6b6d7k17napgn0yc9ymrnn75bps9s71v9";
              license = "agpl3";
            };
            phonetrack = inputs.pkgs.fetchNextcloudApp
            {
              url = githubRelease "julien-nc/phonetrack" "v0.7.6/phonetrack-0.7.6.tar.gz";
              sha256 = "1p15vw7c5c1h08czyxi1r6svjd5hjmnc0i6is4vl3xq2kfjmcyyx";
              license = "agpl3";
            };
            twofactor_webauthn = inputs.pkgs.fetchNextcloudApp
            {
              url = githubRelease "nextcloud-releases/twofactor_webauthn" "v1.3.0/twofactor_webauthn-v1.3.0.tar.gz";
              sha256 = "1akqd5sqz5g58dx3rp15ls7sczviikwwcqn8pj3kii1ffvi9xqx8";
              license = "agpl3";
            };
          };
        };
      nixos.services =
      {
        postgresql = { enable = true; instances.nextcloud = {}; };
        redis.instances.nextcloud.port = 3499;
        nginx = { enable = true; https.${nextcloud.hostname}.global.configName = nextcloud.hostname; };
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
      systemd.services.nextcloud-setup = rec { requires = [ "postgresql.service" ]; after = requires; };
    };
}
