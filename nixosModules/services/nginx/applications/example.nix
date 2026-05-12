{ lib, config, ... }:
{
  options.nixos.services.nginx.applications.example = lib.mkOption
    { type = lib.types.nullOr (lib.types.submodule {}); default = null; };
  config = let inherit (config.nixos.services.nginx.applications) example; in lib.mkIf (example != null)
  {
    nixos.services.nginx.https."example.chn.moe".location."/".static =
      { root = "${config.services.nginx.package}/html"; index = [ "index.html" ]; };
  };
}
