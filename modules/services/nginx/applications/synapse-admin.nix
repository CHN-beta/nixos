{ lib, config, pkgs, ... }:
{
  options.nixos.services.nginx.applications.synapse-admin.instances = lib.mkOption
    { type = lib.types.attrsOf (lib.types.submodule (submoduleInputs: {})); default = {}; };
  config = let inherit (config.nixos.services.nginx.applications.synapse-admin) instances; in
  {
    nixos.services.nginx.https = builtins.mapAttrs
      (n: v: { location."/".static = { root = "${pkgs.synapse-admin-etkecc}"; index = [ "index.html" ]; }; })
      instances;
  };
}
