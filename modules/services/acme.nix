{ lib, config, ... }:
{
  options.nixos.services.acme = lib.mkOption
  {
    type = lib.types.nullOr (lib.types.submodule { options =
    {
      cert = lib.mkOption
      {
        type = lib.types.attrsOf (lib.types.submodule (submoduleInputs: { options =
        {
          domains = lib.mkOption
          {
            type = lib.types.nonEmptyListOf lib.types.nonEmptyStr;
            default = [ submoduleInputs.config._module.args.name ];
          };
          group = lib.mkOption { type = lib.types.nullOr lib.types.nonEmptyStr; default = null; };
        };}));
        default = {};
      };
    };});
    default = null;
  };
  config = let inherit (config.nixos.services) acme; in lib.mkIf (acme != null)
  {
    security.acme =
    {
      acceptTerms = true;
      defaults =
      {
        email = "chn@chn.moe";
        dnsProvider = "cloudflare";
        dnsResolver = "1.1.1.1";
      };
      certs = builtins.listToAttrs (builtins.map
        (cert:
        {
          name = builtins.elemAt cert.value.domains 0;
          value =
          {
            credentialsFile = config.nixos.system.sops.templates."acme/cloudflare.ini".path;
            extraDomainNames = builtins.tail cert.value.domains;
            group = lib.mkIf (cert.value.group != null) cert.value.group;
          };
        })
        (lib.attrsToList acme.cert));
    };
    nixos.system.sops =
    {
      templates."acme/cloudflare.ini".content =
      ''
        CLOUDFLARE_DNS_API_TOKEN=${config.nixos.system.sops.placeholder."acme/token"}
        CLOUDFLARE_PROPAGATION_TIMEOUT=300
      '';
      secrets."acme/token" = {};
    };
  };
}
