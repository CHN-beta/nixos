{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.nixos.services.nginx.applications.synapse-admin = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule { });
    default = null;
  };
  config =
    let
      inherit (config.nixos.services.nginx.applications) synapse-admin;
    in
    lib.mkIf (synapse-admin != null) {
      nixos.services.nginx.https."synapse-admin.chn.moe".location."/".static = {
        root = "${pkgs.synapse-admin-etkecc}";
        index = [ "index.html" ];
      };
    };
}
