{
  lib,
  config,
  pkgs,
  ...
}:
let
  ns = "vps6";
  interface = "ens18";
in
{
  config = lib.mkIf (config.nixos.model.hostname == ns) {
    assertions = [
      {
        assertion = !config.nixos.services.xray.client.enable;
        message = "Currenty xray.client and coredns could not be simutaniusly enabled.";
      }
    ];
    services.coredns = {
      enable = true;
      config = ''
        ts.chn.moe {
          bind ${interface}
          log
          errors

          acl {
            allow type A
            allow type AAAA
            allow type SOA
            allow type CAA
            filter type *
          }

          template IN CAA {
            match ".*"
            rcode NOERROR
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
    nixos.services.geoipupdate = { };
    networking.firewall.allowedUDPPorts = [ 53 ];
  };
}
