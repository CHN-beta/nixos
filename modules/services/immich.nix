{ lib, config, ... }:
{
  options.nixos.services.immich = lib.mkOption
  {
    type = lib.types.nullOr (lib.types.submodule { options =
    {
      hostname = lib.mkOption { type = lib.types.str; default = "photo.chn.moe"; };
    };});
    default = null;
  };
  config = let inherit (config.nixos.services) immich; in lib.mkIf (immich != null)
  {
    services =
    {
      immich =
      {
        enable = true;
        host = "127.0.0.1";
        settings.server.externalDomain = "https://${immich.hostname}";
        redis = { host = "127.0.0.1"; port = 6381; };
        secretsFile = config.nixos.system.sops.templates."immich.env".path;
        accelerationDevices = null;
        database = { enableVectors = false; host = "127.0.0.1"; };
      };
      # immich module bind redis to only interface specified by cfg.redis.host, but we prefer to bind to all interfaces
      redis.servers.immich.bind = lib.mkForce null;
    };
    nixos =
    {
      system.sops.templates."immich.env" =
      {
        owner = config.services.immich.user;
        content = let inherit (config.nixos.system.sops) placeholder; in
        ''
          DB_PASSWORD=${placeholder."postgresql/immich"}
          REDIS_PASSWORD=${placeholder."redis/immich"}
        '';
      };
      services =
      {
        redis.instances.immich.port = 6381;
        postgresql.instances.immich = {};
        nginx.https.${immich.hostname}.location."/".proxy.upstream =
          "http://127.0.0.1:${builtins.toString config.services.immich.port}";
      };
    };
  };
}
