inputs:
{
  options.nixos.services.harmonia = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      hostname = mkOption { type = types.nonEmptyStr; default = "nix-store.chn.moe"; };
      store = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) harmonia; in inputs.lib.mkIf (harmonia != null)
  {
    services.harmonia-dev =
    {
      cache =
      {
        enable = true;
        signKeyPaths = [ inputs.config.nixos.system.sops.secrets."store/signingKey".path ];
        settings = inputs.lib.mkIf (harmonia.store != null)
          { virtual_nix_store = "/nix/store"; real_nix_store = "${harmonia.store}/nix/store"; };
      };
      daemon =
      {
        enable = true;
        dbPath = inputs.lib.mkIf (harmonia.store != null) "${harmonia.store}/nix/var/nix/db/db.sqlite";
      };
    };
    nixos =
    {
      system.sops.secrets."store/signingKey" = {};
      services.nginx.https.${harmonia.hostname}.location."/".proxy.upstream = "http://127.0.0.1:5000";
    };
  };
}
