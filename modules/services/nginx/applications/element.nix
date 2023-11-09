inputs:
{
  options.nixos.services.nginx.applications.element.instances = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.attrsOf (types.submodule (submoduleInputs: { options =
    {
      hostname = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config._module.args.name; };
      defaultServer = mkOption { type = types.nullOr types.nonEmptyStr; default = "element.chn.moe"; };
    };}));
    default = {};
  };
  config =
    let
      inherit (inputs.config.nixos.services.nginx.applications.element) instances;
      inherit (inputs.localLib) attrsToList;
      inherit (builtins) map listToAttrs toString;
    in
    {
      nixos.services.nginx.https = listToAttrs (map
        (instance: with instance.value;
        {
          name = hostname;
          value.location."/".static.root =
            if defaultServer == null then toString inputs.pkgs.element-web
            else toString (inputs.pkgs.element-web.override { conf =
            {
              default_server_config."m.homeserver" =
              {
                base_url = "https://${defaultServer}";
                server_name = defaultServer;
              };
              disable_guests = false;
            };});
        })
        (attrsToList instances));
    };
}
