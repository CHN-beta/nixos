inputs:
{
  options.nixos.services.nginx.applications.nextcloud.instances = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.attrsOf (types.submodule (submoduleInputs: { options =
    {
      hostname = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config._module.args.name; };
      upstream = mkOption { type = types.nonEmptyStr; default = "127.0.0.1"; };
    };}));
    default = {};
  };
  config =
    let
      inherit (inputs.config.nixos.services.nginx.applications.nextcloud) instances;
      inherit (inputs.lib) mkIf mkMerge;
      inherit (inputs.localLib) attrsToList;
      inherit (builtins) map listToAttrs;
    in mkMerge
    [
      (mkIf (instances != {}) { services.nextcloud.maxUploadSize = "10G"; })
      {
        nixos.services.nginx.http = listToAttrs (map
          (instance: { name = instance.hostname; value.rewriteHttps = true; })
          (attrsToList instances));
        services.nginx.virtualHosts = listToAttrs (map
          (instance: { name = instance.hostname; value = inputs.config.services.nextcloud.nginx.recommendedConfig; })
          (attrsToList instances));
      }
    ];
}
