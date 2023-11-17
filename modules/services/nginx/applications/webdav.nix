inputs:
{
  options.nixos.services.nginx.applications.webdav = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.nonEmptyStr; default = "webdav.chn.moe"; };
  };
  config =
    let
      inherit (inputs.config.nixos.services.nginx.applications) webdav;
      inherit (inputs.lib) mkIf;
    in mkIf webdav.enable
    {
      nixos.services.nginx.https."${webdav.hostname}".location."/".static =
        { root = "/srv/webdav"; index = "auto"; charset = "utf-8"; webdav = true; detectAuth.users = [ "chn" ]; };
      systemd =
      {
        tmpfiles.rules = [ "d /srv/webdav 0700 nginx nginx" ];
        services.nginx.serviceConfig.ReadWritePaths = [ "/srv/webdav" ];
      };
    };
}
