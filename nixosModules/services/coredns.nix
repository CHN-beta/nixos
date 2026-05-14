{ lib, config, pkgs, ... }:
{
  options.nixos.services.coredns = lib.mkOption
  {
    type = lib.types.nullOr (lib.types.submodule (submoduleInputs: { options =
    {
      interface = lib.mkOption { type = lib.types.str; };
      ns = lib.mkOption { type = lib.types.str; };
    };}));
    default = null;
  };
  config = let inherit (config.nixos.services) coredns; in lib.mkIf (coredns != null)
  {
    assertions =
    [{
      assertion = !config.nixos.services.xray.client.enable;
      message = "Currenty xray.client and coredns could not be simutaniusly enabled.";
    }];
    services.coredns =
    {
      enable = true;
      config =
      ''
        ts.chn.moe {
          bind ${coredns.interface}
          log
          errors

          acl {
            allow type A
            allow type AAAA
            allow type SOA
            filter type *
          }

          template IN SOA {
            match ".*"
            answer "{{ .Name }} 60 IN SOA ${coredns.ns}. chn.chn.moe. 2023010100 7200 3600 1209600 3600"
          }
          forward . 100.100.100.100

          header {
            response set aa
          }
        }

        . {
          bind ${coredns.interface}
          acl {}
          errors
          log
        }
      '';
    };
    nixos.services.geoipupdate = {};
    networking.firewall.allowedUDPPorts = [ 53 ];
  };
}
