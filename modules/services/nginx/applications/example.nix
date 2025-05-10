inputs:
{
  options.nixos.services.nginx.applications.example = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services.nginx.applications) example; in inputs.lib.mkIf (example != null)
  {
    nixos.services.nginx.https."example.chn.moe".location."/".static =
      { root = "${inputs.config.services.nginx.package}/html"; index = [ "index.html" ]; };
  };
}
