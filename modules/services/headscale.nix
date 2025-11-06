inputs:
{
  options.nixos.services.headscale = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      hostname = mkOption { type = types.nonEmptyStr; default = "headscale.chn.moe"; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) headscale; in inputs.lib.mkIf (headscale != null)
  {
    services.headscale =
    {
      enable = true;
      port = 6538;
      settings =
      {
        server_url = "https://${headscale.hostname}";
        prefixes.v4 = "100.97.101.0/24";
        database.postgres =
        {
          user = "headscale";
          port = 5432;
          password_file = inputs.config.nixos.system.sops.secrets."headscale/postgresql".path;
          name = "headscale";
          host = "127.0.0.1";
        };
        dns = { base_domain = "hs.chn.moe"; override_local_dns = false; };
      };
    };
    nixos =
    {
      services =
      {
        nginx.https.${headscale.hostname}.location."/".proxy =
          { upstream = "http://127.0.0.1:6538"; websocket = true; };
        postgresql.instances.headscale = {};
      };
      system.sops.secrets."headscale/postgresql" = { key = "postgresql/headscale"; owner = "headscale"; };
    };
  };
}
