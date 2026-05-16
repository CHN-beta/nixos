{ lib, config, pkgs, ... }: let ns = "vps6"; interface = "ens18"; in
{
  config = lib.mkIf (config.nixos.model.hostname == ns)
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
        autoroute.chn.moe {
          bind ${interface}
          geoip ${config.services.geoipupdate.settings.DatabaseDirectory}/GeoLite2-Country.mmdb
          log
          errors
          metadata

          template IN SOA {
            match ^autoroute\.chn\.moe\.$
            answer "{{ .Name }} 60 IN SOA ${ns}.chn.moe. chn.chn.moe. 2023010100 7200 3600 1209600 3600"
          }
          template IN A {
            match ^autoroute\.chn\.moe\.$
            answer "{{ .Name }} 60 IN A {{ if eq (.Meta \"geoip/country/code\") \"CN\" }}${pkgs.localPkgs.getAddress "vps6"}{{ else }}${pkgs.localPkgs.getAddress "vps9"}{{ end }}"
          }
          template IN ANY {
            match ".*"
            rcode NOERROR
          }

          header {
            response set aa
          }
        }

        ts.chn.moe {
          bind ${interface}
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
            answer "{{ .Name }} 60 IN SOA ${ns}.chn.moe. chn.chn.moe. 2023010100 7200 3600 1209600 3600"
          }
          forward . 100.100.100.100

          header {
            response set aa
          }
        }

        . {
          bind ${interface}
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
