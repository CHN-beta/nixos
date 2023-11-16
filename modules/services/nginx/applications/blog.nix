inputs:
{
  options.nixos.services.nginx.applications.blog = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (inputs.config.nixos.services.nginx.applications) blog;
      inherit (inputs.lib) mkIf;
    in mkIf blog.enable
    {
      nixos.services.nginx.https."blog.chn.moe".location."/".static =
        { root = "/srv/blog"; index = [ "index.html" ]; };
      systemd.tmpfiles.rules = [ "d /srv/blog 0700 nginx nginx" ];
    };
}
