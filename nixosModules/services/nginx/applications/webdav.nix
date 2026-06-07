{ lib, config, ... }:
{
  options.nixos.services.nginx.applications.webdav.instances = lib.mkOption {
    type = lib.types.attrsOf (
      lib.types.submodule (submoduleInputs: {
        options = {
          hostname = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = submoduleInputs.config._module.args.name;
          };
          path = lib.mkOption {
            type = lib.types.nonEmptyStr;
            default = "/srv/webdav";
          };
          users = lib.mkOption {
            type = lib.types.nonEmptyListOf lib.types.nonEmptyStr;
            default = [ "chn" ];
          };
        };
      })
    );
    default = { };
  };
  config =
    let
      inherit (config.nixos.services.nginx.applications.webdav) instances;
    in
    {
      nixos.services.nginx.https = builtins.listToAttrs (
        builtins.map (site: {
          name = site.hostname;
          value.location."/".static = {
            root = site.path;
            index = "auto";
            charset = "utf-8";
            webdav = true;
            detectAuth.users = site.users;
          };
        }) (builtins.attrValues instances)
      );
      systemd = lib.mkMerge (
        builtins.map (site: {
          tmpfiles.rules = [
            "d ${site.path} 0700 nginx nginx"
            "Z ${site.path} - nginx nginx"
          ];
          services.nginx.serviceConfig.ReadWritePaths = [ site.path ];
        }) (builtins.attrValues instances)
      );
    };
}
