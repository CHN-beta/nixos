{ lib, config, pkgs, ... }:
{
  options.nixos.services.nginx.applications.catalog =
    { enable = lib.mkOption { type = lib.types.bool; default = false; }; };
  config = let inherit (config.nixos.services.nginx.applications) catalog;
    in lib.mkIf catalog.enable
    {
      nixos.services.nginx.https."catalog.chn.moe".location."/".static =
        { root = "/srv/catalog"; index = [ "index.html" ]; };
      systemd.tmpfiles.rules = [ "d /srv/catalog 0700 nginx nginx" "Z /srv/catalog - nginx nginx" ];
    };
}
