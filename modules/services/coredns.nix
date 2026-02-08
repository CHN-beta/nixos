inputs:
{
  options.nixos.services.coredns = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule (submoduleInputs: { options =
    {
      interface = mkOption { type = types.str; };
      ns = mkOption { type = types.str; };
    };}));
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) coredns; in inputs.lib.mkIf (coredns != null)
  {
    services.coredns =
    {
      enable = true;
      config =
      ''
        autoroute.chn.moe {
          bind ${coredns.interface}
          geoip ${inputs.config.services.geoipupdate.settings.DatabaseDirectory}/GeoLite2-Country.mmdb
          log
          errors
          metadata

          template IN SOA {
            match ^autoroute\.chn\.moe\.$
            answer "{{ .Name }} 60 IN SOA ${coredns.ns}. chn.chn.moe. 2023010100 7200 3600 1209600 3600"
          }
          template IN A {
            match ^autoroute\.chn\.moe\.$
            answer "{{.Name}} 60 IN A ${inputs.topInputs.self.config.dns."chn.moe".getAddress "vps6"}"
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
          bind ${coredns.interface}
          log
          errors

          template IN SOA {
            match ".*"
            answer "{{ .Name }} 60 IN SOA ${coredns.ns}. chn.chn.moe. 2023010100 7200 3600 1209600 3600"
          }
          template IN A {
            match ".*"
            fallthrough
          }
          template IN AAAA {
            match ".*"
            fallthrough
          }
          template IN ANY {
            match ".*"
            rcode NOERROR
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
