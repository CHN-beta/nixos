inputs:
{
  options.nixos.services.redis = let inherit (inputs.lib) mkOption types; in
  {
    instances = mkOption
    {
      type = types.attrsOf (types.submodule (submoduleInputs: { options =
      {
        user = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config._module.args.name; };
        passwordFile = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
        port = mkOption { type = types.ints.unsigned; };
      };}));
      default = {};
    };
  };
  config =
    let
      inherit (inputs.config.nixos.services) redis;
      inherit (inputs.localLib) attrsToList;
      inherit (builtins) map listToAttrs filter;
    in
    {
      services.redis.servers = listToAttrs (map
        (server:
        {
          inherit (server) name;
          value =
          {
            enable = true;
            bind = null;
            port = server.value.port;
            user = server.value.user;
            # unixSocket = null; # bug
            unixSocketPerm = 600;
            requirePassFile =
              if server.value.passwordFile == null then inputs.config.sops.secrets."redis/${server.name}".path
              else server.value.passwordFile;
          };
        })
        (attrsToList redis.instances));
      sops.secrets = listToAttrs (map
        (server: { name = "redis/${server.name}"; value.owner = inputs.config.users.users.${server.value.user}.name; })
        (filter (server: server.value.passwordFile == null) (attrsToList redis.instances)));
    };
}
