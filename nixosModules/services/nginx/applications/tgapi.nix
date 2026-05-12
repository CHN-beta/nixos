{ lib, config, ...}:
{
  options.nixos.services.nginx.applications.tgapi = lib.mkOption
    { type = lib.types.nullOr (lib.types.submodule {}); default = null; };
  config = let inherit (config.nixos.services.nginx.applications) tgapi; in lib.mkIf (tgapi != null)
  {
    nixos.services.nginx.https."tgapi.chn.moe".location."/".proxy.upstream = "https://api.telegram.org";
  };
}
