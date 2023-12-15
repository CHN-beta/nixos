inputs:
{
  options.nixos.services.nginx.applications.kkmeeting = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.nonEmptyStr; default = "kkmeeting.chn.moe"; };
  };
  config =
    let
      inherit (inputs.config.nixos.services.nginx.applications) kkmeeting;
      inherit (inputs.lib) mkIf;
    in mkIf kkmeeting.enable
    {
      nixos.services.nginx.https.${kkmeeting.hostname}.location."/".static =
        { root = "/srv/kkmeeting"; index = "auto"; charset = "utf-8"; };
      systemd.tmpfiles.rules = [ "d /srv/kkmeeting 0700 nginx nginx" "Z /srv/kkmeeting - nginx nginx" ];
    };
}
