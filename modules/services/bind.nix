inputs:
{
  options.nixos.services.bind = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule (submoduleInputs: {})); default = null; };
  config = let inherit (inputs.config.nixos.services) bind; in inputs.lib.mkIf (bind != null)
  {
    services.bind =
      let
        chinaZone = inputs.pkgs.writeText "autoroute.chn.moe.china.zone"
        ''
          $TTL 3600
          @ IN SOA vps6.chn.moe. autoroute.chn.moe. (
            2024071301 ; serial
            3600       ; refresh
            600        ; retry
            604800     ; expire
            300        ; minimum
          )
          @ IN NS vps6.chn.moe.
          a   IN  CNAME   vps6.chn.moe.  ; 国际用户解析到C
        '';
        globalZone = inputs.pkgs.writeText "autoroute.chn.moe.zone"
        ''
          $TTL 3600
          @ IN SOA vps6.chn.moe. autoroute.chn.moe. (
            2024071301 ; serial
            3600       ; refresh
            600        ; retry
            604800     ; expire
            300        ; minimum
          )
          @ IN NS vps6.chn.moe.
          a   IN  CNAME   srv3.chn.moe.  ; 国际用户解析到C
        '';
        nullZone = inputs.pkgs.writeText "null.zone" "";
      in
      {
        enable = true;
        package = inputs.pkgs.bind.overrideAttrs
          (prev: { buildInputs = prev.buildInputs ++ [ inputs.pkgs.libmaxminddb ]; });
        listenOn = [(inputs.topInputs.self.config.dns."chn.moe".getAddress "vps6")];
        extraOptions =
        ''
          recursion no;
          geoip-directory "${inputs.config.services.geoipupdate.settings.DatabaseDirectory}";
        '';
        extraConfig =
        ''
          acl "china" {
            geoip country CN;
          };

          view "china" {
            match-clients { china; };
            zone "autoroute.chn.moe" {
              type master;
              file "${chinaZone}";
            };
            zone "." {
              type hint;
              file "${nullZone}";
            };
          };
          view "global-view" {
            match-clients { any; };
            zone "example.com" {
              type master;
              file "${globalZone}";
            };
            zone "." {
              type hint;
              file "${nullZone}";
            };
          };
        '';
      };
    nixos.services.geoipupdate = {};
    networking.firewall.allowedUDPPorts = [ 53 ];
  };
}
