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
      package = inputs.pkgs.nextcloud29;
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
          githubRelease = repo: file: "https://github.com/${repo}/releases/download/${file}";
        in
        {
          # nix-prefetch-url --unpack
          maps = inputs.pkgs.fetchNextcloudApp
          {
            url = githubRelease "nextcloud/maps" "v1.4.0/maps-1.4.0.tar.gz";
            sha256 = "1gqms3rrdpjmpb1h5d72b4lwbvsl8p10zwnkhgnsmvfcf93h3r1c";
            license = "agpl3Only";
          };
          phonetrack = inputs.pkgs.fetchNextcloudApp
          {
            url = githubRelease "julien-nc/phonetrack" "v0.8.1/phonetrack-0.8.1.tar.gz";
            sha256 = "1i28xgzp85yb44ay2l2zw18fk00yd6fh6yddj92gdrljb3w9zpap";
            license = "agpl3Only";
          };
          twofactor_webauthn = inputs.pkgs.fetchNextcloudApp
          {
            url = githubRelease "nextcloud-releases/twofactor_webauthn" "v1.4.0/twofactor_webauthn-v1.4.0.tar.gz";
            sha256 = "0llxakzcdcy9hscyzw3na5zp1p57h03w5fmm0gs9g62k1b88k6kw";
            license = "agpl3Only";
          };
          calendar = inputs.pkgs.fetchNextcloudApp
          {
            url = githubRelease "nextcloud-releases/calendar" "v4.7.6/calendar-v4.7.6.tar.gz";
            sha256 = "09rsp5anpaqzwmrixza5qh12vmq9hd3an045064vm3rnynz537qc";
            license = "agpl3Only";
          };
        };
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
