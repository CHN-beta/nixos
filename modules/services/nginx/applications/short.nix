{ lib, config, ... }:
{
  options.nixos.services.nginx.applications.short = lib.mkOption
    { type = lib.types.nullOr (lib.types.submodule {}); default = null; };
  config = let inherit (config.nixos.services.nginx.applications) short; in lib.mkIf (short != null)
  {
    nixos.services.nginx.https."s.chn.moe".location =
    {
      "/k".return.return = "302 https://kanggroup.xmu.edu.cn";
    };
  };
}
