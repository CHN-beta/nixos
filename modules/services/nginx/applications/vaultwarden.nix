inputs:
{
  options.nixos.services.nginx.applications.vaultwarden = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.nonEmptyStr; default = "vaultwarden.chn.moe"; };
    upstream = mkOption
    {
      type = types.oneOf [ types.nonEmptyStr (types.submodule { options =
      {
        address = mkOption { type = types.nonEmptyStr; default = "127.0.0.1"; };
        port = mkOption { type = types.ints.unsigned; default = 8000; };
        websocketPort = mkOption { type = types.ints.unsigned; default = 3012; };
      };})];
      default = {};
    };
  };
  config =
    let
      inherit (inputs.config.nixos.services.nginx.applications) vaultwarden;
      inherit (builtins) listToAttrs;
      inherit (inputs.lib) mkIf;
    in mkIf vaultwarden.enable
    {
      nixos.services.nginx.http."${vaultwarden.hostname}" =
      {
        rewriteHttps = true;
        locations = let upstream = vaultwarden.upstream; in (listToAttrs (map
          (location: { name = location; value.proxy =
          {
            upstream = "http://${upstream.address or upstream}:${builtins.toString upstream.port or 8000}";
            setHeaders = { Host = vaultwarden.hostname; Connection = ""; };
          };})
          [ "/" "/notifications/hub/negotiate" ]))
          // { "/notifications/hub".proxy =
          {
            upstream =
              "http://${upstream.address or upstream}:${builtins.toString upstream.websocketPort or 3012}";
            websocket = true;
            setHeaders.Host = vaultwarden.hostname;
          };};
      };
    };
}
