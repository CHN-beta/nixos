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
          $ORIGIN autoroute.chn.moe.
          $TTL 3600
          @ IN SOA vps6.chn.moe. chn.chn.moe. (
            2024071301 ; serial
            3600       ; refresh
            600        ; retry
            604800     ; expire
            300        ; minimum
          )
          @ IN NS vps6.chn.moe.
          @ IN A ${inputs.topInputs.self.config.dns."chn.moe".getAddress "vps6"}
        '';
        globalZone = inputs.pkgs.writeText "autoroute.chn.moe.zone"
        ''
          $ORIGIN autoroute.chn.moe.
          $TTL 3600
          @ IN SOA vps6.chn.moe. chn.chn.moe. (
            2024071301 ; serial
            3600       ; refresh
            600        ; retry
            604800     ; expire
            300        ; minimum
          )
          @ IN NS vps6.chn.moe.
          @ IN A ${inputs.topInputs.self.config.dns."chn.moe".getAddress "vps4"}
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
          view "global" {
            match-clients { any; };
            zone "autoroute.chn.moe" {
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
