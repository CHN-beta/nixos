inputs:
{
  options.nixos.services.acme = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    certs = mkOption
    {
      type = types.listOf types.oneOf [ types.nonEmptyStr (types.listOf types.nonEmptyStr) ];
      default = [];
    };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos.services) acme;
      inherit (builtins) map listToAttrs;
    in mkIf acme.enable
    {
      security.acme =
      {
        acceptTerms = true;
        defaults.email = "chn@chn.moe";
        certs = listToAttrs (map
          (cert:
          {
            name = if builtins.typeOf cert == "string" then cert else builtins.elemAt cert 0;
            value =
            {
              dnsResolver = "8.8.8.8";
              dnsProvider = "cloudflare";
              credentialsFile = inputs.config.sops.secrets."acme/cloudflare.ini".path;
              extraDomainNames = if builtins.typeOf cert == "string" then [] else builtins.tail cert;
            };
          })
          acme.certs);
      };
      sops.secrets."acme/cloudflare.ini" = {};
    };
}
