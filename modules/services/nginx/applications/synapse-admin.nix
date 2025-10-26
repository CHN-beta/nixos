inputs:
{
  options.nixos.services.nginx.applications.synapse-admin.instances = let inherit (inputs.lib) mkOption types; in
    mkOption { type = types.attrsOf (types.submodule (submoduleInputs: {})); default = {}; };
  config = let inherit (inputs.config.nixos.services.nginx.applications.synapse-admin) instances; in
  {
    nixos.services.nginx.https = builtins.mapAttrs
      (n: v: { location."/".static = { root = "${inputs.pkgs.synapse-admin-etkecc}"; index = [ "index.html" ]; }; })
      instances;
  };
}
