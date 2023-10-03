inputs:
{
  options.nixos.services.nginx.applications.misskey.instances = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.attrsOf (types.submodule (submoduleInputs: { options =
    {
      hostname = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config._module.args.name; };
      upstream = mkOption
      {
        type = types.oneOf [ types.nonEmptyStr (types.submodule { options =
        {
          address = mkOption { type = types.nonEmptyStr; default = "127.0.0.1"; };
          port = mkOption { type = types.ints.unsigned; default = 9726; };
        };})];
        default = "127.0.0.1:9726";
      };
    };}));
    default = {};
  };
  config =
    let
      inherit (inputs.config.nixos.services.nginx.applications.misskey) instances;
      inherit (inputs.localLib) attrsToList;
      inherit (builtins) map listToAttrs toString;
    in
    {
      nixos.services.nginx.http = listToAttrs (map
        (proxy: with proxy.value;
        {
          name = hostname;
          value =
          {
            rewriteHttps = true;
            locations."/".proxy =
            {
              upstream = if builtins.typeOf upstream == "string" then "http://${upstream}"
                else "http://${upstream.address}:${toString upstream.port}";
              websocket = true;
              setHeaders.Host = hostname;
            };
          };
        })
        (attrsToList instances));
    };
}
