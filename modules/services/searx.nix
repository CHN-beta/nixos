inputs:
{
  options.nixos.services.searx = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      hostname = mkOption { type = types.nonEmptyStr; default = "search.chn.moe"; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) searx; in inputs.lib.mkIf (searx != null)
  {
    services.searx =
    {
      enable = true;
      settings.server = { port = 8081; bind_address = "127.0.0.1"; secret_key = "@SEARX_SECRET_KEY@"; };
      environmentFile = inputs.config.sops.templates."searx.env".path;
    };
    sops =
    {
      templates."searx.env".content = let inherit (inputs.config.sops) placeholder; in
      ''
        SEARX_SECRET_KEY=${placeholder."searx/secret-key"}
      '';
      secrets."searx/secret-key" = {};
    };
    nixos.services.nginx.https.${searx.hostname}.location."/".proxy.upstream = "http://127.0.0.1:8081";
  };
}
