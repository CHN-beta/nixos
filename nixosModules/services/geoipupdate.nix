inputs: {
  options.nixos.services.geoipupdate =
    let
      inherit (inputs.lib) mkOption types;
    in
    mkOption {
      type = types.nullOr (types.submodule { });
      default = null;
    };
  config =
    let
      inherit (inputs.config.nixos.services) geoipupdate;
    in
    inputs.lib.mkIf (geoipupdate != null) {
      services.geoipupdate = {
        enable = true;
        settings = {
          AccountID = 901296;
          LicenseKey = inputs.config.nixos.system.sops.secrets."maxmind".path;
          EditionIDs = [
            "GeoLite2-ASN"
            "GeoLite2-City"
            "GeoLite2-Country"
          ];
        };
      };
      nixos.system.sops.secrets."maxmind" = { };
    };
}
