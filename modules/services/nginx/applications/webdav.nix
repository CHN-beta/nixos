inputs:
{
  options.nixos.services.nginx.applications.webdav.instances = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.attrsOf (types.submodule (submoduleInputs: { options =
    {
      hostname = mkOption { type = types.nonEmptyStr; default = submoduleInputs.config._module.args.name; };
      path = mkOption { type = types.nonEmptyStr; default = "/srv/webdav"; };
      users = mkOption { type = types.nonEmptyListOf types.nonEmptyStr; default = [ "chn" ]; };
    };}));
    default = {};
  };
  config =
    let
      inherit (inputs.config.nixos.services.nginx.applications.webdav) instances;
      inherit (builtins) map listToAttrs attrNames;
      inherit (inputs.lib) mkMerge;
    in
    {
      nixos.services.nginx.https = listToAttrs (map
        (site:
        {
          name = site.hostname;
          value.location."/".static =
            { root = site.path; index = "auto"; charset = "utf-8"; webdav = true; detectAuth.users = site.users; };
        })
        (attrNames instances));
      systemd = mkMerge (map
        (site:
        {
          tmpfiles.rules = [ "d ${site.path} 0700 nginx nginx" ];
          services.nginx.serviceConfig.ReadWritePaths = [ site.path ];
        })
        (attrNames instances));
    };
}
