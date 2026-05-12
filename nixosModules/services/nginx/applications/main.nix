{ lib, config, ... }:
{
  options.nixos.services.nginx.applications.main = lib.mkOption
    { type = lib.types.nullOr (lib.types.submodule {}); default = null; };
  config = let inherit (config.nixos.services.nginx.applications) main; in lib.mkIf (main != null)
  {
    nixos.services.nginx.https."chn.moe".location =
    {
      "/".return.return = "302 https://xn--s8w913fdga.chn.moe/@chn";
      "/.well-known/matrix/server".proxy = { setHeaders.Host = "matrix.chn.moe"; upstream = "https://matrix.chn.moe"; };
    };
  };
}
