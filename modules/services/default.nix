inputs:
{
  imports = inputs.localLib.mkModules
  [
    ./postgresql.nix
    ./redis.nix
    ./rsshub.nix
    ./misskey.nix
    ./nginx
    ./meilisearch.nix
    ./xray.nix
    ./coturn.nix
    ./synapse.nix
    ./phpfpm.nix
    ./xrdp.nix
    ./groupshare.nix
    ./acme.nix
    ./samba.nix
    ./sshd.nix
    ./vaultwarden.nix
    ./frp.nix
    ./beesd.nix
    ./snapper.nix
    ./mariadb.nix
    ./photoprism.nix
    ./nextcloud.nix
    ./freshrss.nix
    ./kmscon.nix
    ./fontconfig.nix
    ./nix-serve.nix
    ./send.nix
    ./huginn.nix
    ./httpua
    ./fz-new-order
    ./httpapi.nix
    ./mirism.nix
    ./mastodon.nix
  ];
  options.nixos.services = let inherit (inputs.lib) mkOption types; in
  {
    firewall.trustedInterfaces = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
    smartd.enable = mkOption { type = types.bool; default = false; };
    wallabag.enable = mkOption { type = types.bool; default = false; };
    noisetorch.enable = mkOption { type = types.bool; default = inputs.config.nixos.system.gui.preferred; };
  };
  config =
    let
      inherit (inputs.lib) mkMerge mkIf;
      inherit (inputs.localLib) stripeTabs attrsToList;
      inherit (inputs.config.nixos) services;
      inherit (builtins) map listToAttrs toString;
    in mkMerge
    [
      { networking.firewall.trustedInterfaces = services.firewall.trustedInterfaces; }
      (mkIf services.smartd.enable { services.smartd.enable = true; })
      (
        mkIf services.wallabag.enable
        {
          virtualisation.oci-containers.containers.wallabag =
          {
            image = "wallabag/wallabag:2.6.2";
            imageFile = inputs.pkgs.dockerTools.pullImage
            {
              imageName = "wallabag/wallabag";
              imageDigest = "sha256:241e5c71f674ee3f383f428e8a10525cbd226d04af58a40ce9363ed47e0f1de9";
              sha256 = "0zflrhgg502w3np7kqmxij8v44y491ar2qbk7qw981fysia5ix09";
              finalImageName = "wallabag/wallabag";
              finalImageTag = "2.6.2";
            };
            ports = [ "127.0.0.1:4398:80/tcp" ];
            extraOptions = [ "--add-host=host.docker.internal:host-gateway" ];
            environmentFiles = [ inputs.config.sops.templates."wallabag/env".path ];
          };
          sops =
          {
            templates."wallabag/env".content =
              let
                placeholder = inputs.config.sops.placeholder;
              in
              ''
                SYMFONY__ENV__DATABASE_DRIVER=pdo_pgsql
                SYMFONY__ENV__DATABASE_HOST=host.docker.internal
                SYMFONY__ENV__DATABASE_PORT=5432
                SYMFONY__ENV__DATABASE_NAME=wallabag
                SYMFONY__ENV__DATABASE_USER=wallabag
                SYMFONY__ENV__DATABASE_PASSWORD=${placeholder."postgresql/wallabag"}
                SYMFONY__ENV__REDIS_HOST=host.docker.internal
                SYMFONY__ENV__REDIS_PORT=8790
                SYMFONY__ENV__REDIS_PASSWORD=${placeholder."redis/wallabag"}
                SYMFONY__ENV__SERVER_NAME=wallabag.chn.moe
                SYMFONY__ENV__DOMAIN_NAME=https://wallabag.chn.moe
                SYMFONY__ENV__TWOFACTOR_AUTH=false
              '';
              # SYMFONY__ENV__MAILER_DSN=smtp://bot%%40chn.moe@${placeholder."mail/bot-encoded"}:mail.chn.moe
              # SYMFONY__ENV__FROM_EMAIL=bot@chn.moe
              # SYMFONY__ENV__TWOFACTOR_SENDER=bot@chn.moe
            secrets."mail/bot-encoded" = {};
          };
          nixos =
          {
            services =
            {
              nginx =
              {
                enable = true;
                https."wallabag.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:4398";
              };
              postgresql = { enable = true; instances.wallabag = {}; };
              redis.instances.wallabag = { user = "root"; port = 8790; };
            };
            # TODO: root docker use config of rootless docker?
            virtualization.docker.enable = true;
          };
        }
      )
      (mkIf services.noisetorch.enable { programs.noisetorch.enable = true; })
    ];
}
