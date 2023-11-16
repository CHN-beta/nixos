inputs:
{
  options.nixos.services.httpapi = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.nonEmptyStr; default = "api.chn.moe"; };
  };
  config =
    let
      inherit (inputs.config.nixos.services) httpapi;
      inherit (inputs.lib) mkIf;
      inherit (builtins) toString;
    in mkIf httpapi.enable
    {
      nixos.services =
      {
        phpfpm.instances.httpapi = {};
        nginx.https.${httpapi.hostname}.location =
        {
          "/led".static =
          {
            root = "/srv/api";
            detectAuth.users = [ "chn" ];
          }
        }
        php =
        {
          root = toString ./.;
          fastcgiPass = inputs.config.nixos.services.phpfpm.instances.httpua.fastcgi;
        };
      };
    };
}
