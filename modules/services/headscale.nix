inputs:
{
  options.nixos.services.headscale = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) headscale; in inputs.lib.mkIf (headscale != null)
  {
    services.headscale =
    {
      enable = true;
      port = 6538;
      settings =
      {
        server_url = "https://headscale.chn.moe";
        prefixes.v4 = "100.97.101.0/24";
        database.postgres =
        {
          user = "headscale";
          port = 5432;
          password_file = inputs.config.nixos.system.sops.secrets."headscale/postgresql".path;
          name = "headscale";
          host = "127.0.0.1";
        };
        dns = { base_domain = "ts.chn.moe"; override_local_dns = false; };
      };
    };
    nixos =
    {
      services =
      {
        nginx.https."headscale.chn.moe".location."/".proxy.upstream = "http://127.0.0.1:6538";
        postgresql.instances.headscale = {};
      };
      system.sops.secrets."headscale/postgresql" = { key = "postgresql/headscale"; owner = "headscale"; };
    };
  };
}
