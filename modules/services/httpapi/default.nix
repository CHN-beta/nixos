inputs:
{
  options.nixos.services.httpua = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    hostname = mkOption { type = types.nonEmptyStr; default = "ua.chn.moe"; };
  };
  config =
    let
      inherit (inputs.config.nixos.services) httpua;
      inherit (inputs.lib) mkIf;
      inherit (builtins) toString;
    in mkIf httpua.enable
    {
      nixos.services =
      {
        phpfpm.instances.httpua = {};
        nginx.http.${httpua.hostname}.php =
        {
          root = toString ./.;
          fastcgiPass = inputs.config.nixos.services.phpfpm.instances.httpua.fastcgi;
        };
      };
    };
}
