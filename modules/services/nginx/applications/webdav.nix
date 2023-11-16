inputs:
{
  options.nixos.services.nginx.applications.webdav = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (inputs.config.nixos.services.nginx.applications) webdav;
      inherit (inputs.lib) mkIf;
    in mkIf webdav.enable
    {
      nixos.services.nginx.https."webdav.chn.moe".location."/".static =
      {
        root = "/srv/webdav";
        index = "auto";
        charset = "utf-8";
        webdav = true;
        detectAuth.users = [ "chn" ];
      };
      systemd =
      {
        tmpfiles.rules = [ "d /srv/webdav 0700 nginx nginx" ];
        services.nginx.serviceConfig.ReadWritePaths = [ "/srv/webdav" ];
      };
    };
}
