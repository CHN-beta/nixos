{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.nixos.services.acme = lib.mkOption {
    type = lib.types.nullOr (
      lib.types.submodule {
        options = {
          cert = lib.mkOption {
            type = lib.types.attrsOf (
              lib.types.submodule (submoduleInputs: {
                options = {
                  domains = lib.mkOption {
                    type = lib.types.nonEmptyListOf lib.types.nonEmptyStr;
                    default = [ submoduleInputs.config._module.args.name ];
                  };
                  group = lib.mkOption {
                    type = lib.types.nullOr lib.types.nonEmptyStr;
                    default = null;
                  };
                };
              })
            );
            default = { };
          };
        };
      }
    );
    default = null;
  };
  config =
    let
      inherit (config.nixos.services) acme;
    in
    lib.mkIf (acme != null) {
      security.acme = {
        acceptTerms = true;
        defaults = {
          email = "chn@chn.moe";
          dnsProvider = "cloudflare";
          dnsResolver = "1.1.1.1";
          credentialFiles.CLOUDFLARE_DNS_API_TOKEN_FILE = config.nixos.system.sops.secrets."acme/token".path;
          environmentFile = pkgs.writeText "acme-env" "CLOUDFLARE_PROPAGATION_TIMEOUT=600";
          extraLegoFlags = [ "--dns.propagation-wait=300s" ];
        };
        certs =
          acme.cert
          |> lib.mapAttrs' (
            n: v:
            lib.nameValuePair (lib.elemAt v.domains 0) {
              extraDomainNames = builtins.tail v.domains;
              group = lib.mkIf (v.group != null) v.group;
            }
          );
      };
      nixos.system.sops.secrets."acme/token" = { };
    };
}
