inputs:
{
  options.nixos.services.nix-serve = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      hostname = mkOption { type = types.nonEmptyStr; default = "nix-store.chn.moe"; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) nix-serve; in inputs.lib.mkIf (nix-serve != null)
  {
    services.nix-serve =
    {
      enable = true;
      openFirewall = true;
      secretKeyFile = inputs.config.sops.secrets."store/signingKey".path;
    };
    sops.secrets."store/signingKey" = {};
    nixos.services.nginx =
      { enable = true; https.${nix-serve.hostname}.location."/".proxy.upstream = "http://127.0.0.1:5000"; };
  };
}
