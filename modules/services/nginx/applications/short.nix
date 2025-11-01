inputs:
{
  options.nixos.services.nginx.applications.short = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services.nginx.applications) short; in inputs.lib.mkIf (short != null)
  {
    nixos.services.nginx.https."s.chn.moe".location =
    {
      "/k".return.return = "302 https://kanggroup.xmu.edu.cn";
    };
  };
}
