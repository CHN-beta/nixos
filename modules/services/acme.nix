inputs:
{
  options.nixos.services.acme = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    cert = mkOption
    {
      type = types.attrsOf (types.submodule (submoduleInputs: { options =
      {
        domains = mkOption
          { type = types.nonEmptyListOf types.nonEmptyStr; default = [ submoduleInputs.config._module.args.name ]; };
        group = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
      };}));
      default = {};
    };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos.services) acme;
      inherit (builtins) map listToAttrs;
      inherit (inputs.localLib) attrsToList;
    in mkIf acme.enable
    {
      security.acme =
      {
        acceptTerms = true;
        defaults.email = "chn@chn.moe";
        certs = listToAttrs (map
          (cert:
          {
            name = builtins.elemAt cert.value.domains 0;
            value =
            {
              dnsResolver = "8.8.8.8";
              dnsProvider = "cloudflare";
              credentialsFile = inputs.config.sops.secrets."acme/cloudflare.ini".path;
              extraDomainNames = builtins.tail cert.value.domains;
              group = mkIf (cert.value.group != null) cert.value.group;
            };
          })
          (attrsToList acme.cert));
      };
      sops.secrets."acme/cloudflare.ini" = {};
    };
}
