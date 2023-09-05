inputs:
{
  options.nixos.services.xrdp = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    port = mkOption { type = types.ints.unsigned; default = 3389; };
    hostname = mkOption { type = types.nullOr types.str; default = null; };
  };
  config =
    let
      inherit (inputs.lib) mkMerge mkIf;
      inherit (inputs.localLib) stripeTabs attrsToList;
      inherit (inputs.config.nixos.services) xrdp;
      inherit (builtins) map listToAttrs concatStringsSep toString filter attrValues;
    in mkMerge
    [
      {
        services.xrdp =
        {
          enable = true;
          port = xrdp.port;
          openFirewall = true;
          defaultWindowManager = "startplasma-x11";
        };
      }
      (
        mkIf (xrdp.hostname != null)
        {
          services.xrdp = let keydir = inputs.config.security.acme.certs.${xrdp.hostname}.directory; in
            { sslCert = "${keydir}/full.pem"; sslKey = "${keydir}/key.pem"; };
          nixos.services.acme = { enable = true; certs = [ xrdp.hostname ]; };
        }
      )
    ];
}
