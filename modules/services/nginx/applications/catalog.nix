inputs:
{
  options.nixos.services.nginx.applications.catalog = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (inputs.config.nixos.services.nginx.applications) catalog;
      inherit (inputs.lib) mkIf;
    in mkIf catalog.enable
    {
      nixos.services.nginx.https."catalog.chn.moe".location."/".static =
        { root = "/srv/catalog"; index = [ "index.html" ]; };
      systemd.tmpfiles.rules = let perm = "/srv/catalog 0700 nginx nginx"; in [ "d ${perm}" "Z ${perm}" ];
    };
}
