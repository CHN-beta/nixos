{ lib, config, ... }:
{
  options.nixos.services.nginx.applications.catalog = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule { });
    default = null;
  };
  config =
    let
      inherit (config.nixos.services.nginx.applications) catalog;
    in
    lib.mkIf (catalog != null) {
      nixos.services.nginx.https."catalog.chn.moe".location."/".static = {
        root = "/srv/catalog";
        index = [ "index.html" ];
      };
      systemd.tmpfiles.rules = [
        "d /srv/catalog 0700 nginx nginx"
        "Z /srv/catalog - nginx nginx"
      ];
    };
}
