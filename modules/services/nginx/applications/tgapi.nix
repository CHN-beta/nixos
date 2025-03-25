inputs:
{
  options.nixos.services.nginx.applications.tgapi = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services.nginx.applications) tgapi; in inputs.lib.mkIf (tgapi != null)
  {
    nixos.services.nginx.https."tgapi.chn.moe".location."/".proxy.upstream = "https://api.telegram.org";
  };
}
