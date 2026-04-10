{ lib, config, pkgs, ... }:
{
  options.nixos.services.nginx.applications.element.instances = lib.mkOption
  {
    type = lib.types.attrsOf (lib.types.submodule (submoduleInputs: { options =
    {
      hostname = lib.mkOption { type = lib.types.nonEmptyStr; default = submoduleInputs.config._module.args.name; };
      defaultServer = lib.mkOption { type = lib.types.nullOr lib.types.nonEmptyStr; default = "matrix.chn.moe"; };
    };}));
    default = {};
  };
  config = let inherit (config.nixos.services.nginx.applications.element) instances; in
  {
    nixos.services.nginx.https = builtins.listToAttrs (builtins.map
      (instance: with instance.value;
      {
        name = hostname;
        value.location."/".static =
        {
          root =
            if defaultServer == null then builtins.toString pkgs.element-web
            else builtins.toString (pkgs.element-web.override { conf =
            {
              default_server_config."m.homeserver" =
                { base_url = "https://${defaultServer}"; server_name = defaultServer; };
              disable_guests = false;
            };});
          index = [ "index.html" ];
        };
      })
      (lib.attrsToList instances));
  };
}
