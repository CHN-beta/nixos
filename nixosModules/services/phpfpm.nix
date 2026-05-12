{ lib, config, ... }:
{
  options.nixos.services.phpfpm.instances = lib.mkOption
  {
    type = lib.types.attrsOf (lib.types.submodule (submoduleInputs: { options =
    {
      fastcgi = lib.mkOption
      {
        type = lib.types.nonEmptyStr;
        readOnly = true;
        default = "unix:${config.services.phpfpm.pools.${submoduleInputs.config._module.args.name}.socket}";
      };
    };}));
    default = {};
  };
  config = let inherit (config.nixos.services) phpfpm; in
  {
    services.phpfpm.pools = phpfpm.instances
      |> (builtins.mapAttrs (n: v:
      {
        user = n;
        group = config.users.users.${n}.group;
        settings =
        {
          "pm" = "ondemand";
          "pm.max_children" = 4;
          "pm.process_idle_timeout" = "60s";
          "pm.max_requests" = 128;
          "listen.owner" = config.services.nginx.user;
          "listen.group" = config.services.nginx.group;
        };
      }));
    users =
    {
      users = phpfpm.instances
        |> (builtins.mapAttrs (n: v:
          { uid = config.nixos.user.uid.${n}; group = n; extraGroups = [ "nginx" ]; isSystemUser = true; }));
      groups = builtins.mapAttrs (n: v: { gid = config.nixos.user.gid.${n}; }) phpfpm.instances;
    };
  };
}
