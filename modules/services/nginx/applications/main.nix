inputs:
{
  options.nixos.services.nginx.applications.main = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services.nginx.applications) main; in inputs.lib.mkIf (main != null)
  {
    nixos.services.nginx.https."chn.moe".location =
    {
      "/".return.return = "302 https://xn--s8w913fdga.chn.moe/@chn";
      "/.well-known/matrix/server".proxy = { setHeaders.Host = "matrix.chn.moe"; upstream = "https://matrix.chn.moe"; };
    };
  };
}
