inputs:
{
  options.nixos.services.coturn = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      hostname = mkOption { type = types.str; default = "coturn.chn.moe"; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) coturn; in inputs.lib.mkIf (coturn != null)
  {
    services.coturn = let keydir = inputs.config.security.acme.certs.${coturn.hostname}.directory; in
    {
      enable = true;
      use-auth-secret = true;
      static-auth-secret-file = inputs.config.sops.secrets."coturn/auth-secret".path;
      realm = coturn.hostname;
      cert = "${keydir}/full.pem";
      pkey = "${keydir}/key.pem";
      no-cli = true;
    };
    sops.secrets."coturn/auth-secret".owner = inputs.config.systemd.services.coturn.serviceConfig.User;
    nixos.services.acme.cert.${coturn.hostname}.group = inputs.config.systemd.services.coturn.serviceConfig.Group;
    networking.firewall = with inputs.config.services.coturn;
    {
      allowedUDPPorts = [ listening-port tls-listening-port ];
      allowedTCPPorts = [ listening-port tls-listening-port ];
      allowedUDPPortRanges = [{ from = min-port; to = max-port; }];
    };
  };
}
