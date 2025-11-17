inputs:
{
  options.nixos.services.coredns = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule (submoduleInputs: { options =
    {
      interface = mkOption { type = types.str; };
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

          view china {
            expr metadata('geoip/country/code') == 'CN'
          }
          template IN A autoroute.chn.moe {
            match ^autoroute\.chn\.moe\.$
            answer "{{.Name}} 60 IN A ${inputs.topInputs.self.config.dns."chn.moe".getAddress "vps6"}"
          }
          template IN AAAA autoroute.chn.moe {
            match ^autoroute\.chn\.moe\.$
            rcode NOERROR
          }
          header {
            response set aa
          }
        }

        autoroute.chn.moe {
          bind ${coredns.interface}
          log
          errors
          metadata

          template IN A autoroute.chn.moe {
            match ^autoroute\.chn\.moe\.$
            answer "{{.Name}} 60 IN A ${inputs.topInputs.self.config.dns."chn.moe".getAddress "vps9"}"
          }
          template IN AAAA autoroute.chn.moe {
            match ^autoroute\.chn\.moe\.$
            rcode NOERROR
          }
          header {
            response set aa
          }
        }

        ts.chn.moe {
          bind ${coredns.interface}
          forward . 100.100.100.100
          header {
            response set aa
          }
          log
          errors
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
