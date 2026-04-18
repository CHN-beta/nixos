{ lib, config, ... }:
{
  options.nixos.services.redis =
  {
    instances = lib.mkOption
    {
      type = lib.types.attrsOf (lib.types.submodule (submoduleInputs: { options =
      {
        user = lib.mkOption { type = lib.types.nonEmptyStr; default = submoduleInputs.config._module.args.name; };
        port = lib.mkOption { type = lib.types.ints.unsigned; };
      };}));
      default = {};
    };
  };
  config = let inherit (config.nixos.services) redis; in
  {
    services.redis.servers = redis.instances
      |> builtins.mapAttrs (n: v:
      {
        enable = true;
        bind = null;
        port = v.port;
        user = v.user;
        # unixSocket = null; # bug
        unixSocketPerm = 600;
        requirePassFile = config.nixos.system.sops.secrets."redis/${n}".path;
      });
    nixos.system.sops.secrets = redis.instances
      |> lib.mapAttrs' (n: v: lib.nameValuePair "redis/${n}" { owner = v.user; });
    systemd.services = redis.instances
      |> lib.mapAttrs' (n: v: lib.nameValuePair "redis-${n}" { serviceConfig.TimeoutStartSec = 0; });
  };
}
