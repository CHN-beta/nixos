inputs:
{
  options.nixos.services.phpfpm = let inherit (inputs.lib) mkOption types; in
  {
    instances = mkOption
    {
      type = types.attrsOf (types.submodule (submoduleInputs: { options =
      {
        user = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
        group = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
        package = mkOption { type = types.nullOr types.package; default = inputs.pkgs.php; };
        fastcgi = mkOption
        {
          type = types.nonEmptyStr;
          readOnly = true;
          default = "unix:${inputs.config.services.phpfpm.pools.${submoduleInputs.config._module.args.name}.socket}";
        };
      };}));
      default = {};
    };
  };
  config =
  let
    inherit (builtins) map listToAttrs filter;
    inherit (inputs.localLib) attrsToList;
    inherit (inputs.config.nixos.services) phpfpm;
  in
  {
    services.phpfpm.pools = listToAttrs (map
      (pool:
      {
        inherit (pool) name;
        value = rec
        {
          user = if pool.value.user == null then pool.name else pool.value.user;
          group = if pool.value.group == null then inputs.config.users.users.${user}.group else pool.value.group;
          phpPackage = pool.value.package;
          settings =
          {
            "pm" = "ondemand";
            "pm.max_children" = 4;
            "pm.process_idle_timeout" = "60s";
            "pm.max_requests" = 128;
            "listen.owner" = inputs.config.services.nginx.user;
            "listen.group" = inputs.config.services.nginx.group;
          };
        };
      })
      (attrsToList phpfpm.instances));
    users =
    {
      users = listToAttrs (map
        (pool: { inherit (pool) name; value = { isSystemUser = true; group = pool.name; extraGroups = [ "nginx" ]; }; })
        (filter (pool: pool.value.user == null) (attrsToList phpfpm.instances)));
      groups = listToAttrs (map
        (pool: { inherit (pool) name; value = {}; })
        (filter (pool: pool.value.user == null) (attrsToList phpfpm.instances)));
    };
  };
}
