inputs:
{
  options.nixos.services.nginx.applications.synapse-admin.instances =
    let inherit (inputs.lib) mkOption types; in mkOption
    {
      type = types.attrsOf (types.submodule (submoduleInputs: { options =
        { hostname = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config._module.args.name; }; };}));
      default = {};
    };
  config =
    let
      inherit (inputs.config.nixos.services.nginx.applications.synapse-admin) instances;
      inherit (inputs.localLib) attrsToList;
      inherit (builtins) map listToAttrs;
    in
    {
      nixos.services.nginx.http = listToAttrs (map
        (http: with http.value;
        {
          name = hostname;
          value =
          {
            rewriteHttps = true;
            locations."/".static.root = "${inputs.pkgs.synapse-admin}/share/synapse-admin";
          };
        })
        (attrsToList instances));
    };
}
