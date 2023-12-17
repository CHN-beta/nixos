inputs:
{
  options.nixos.services.wireguard = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    peers = mkOption { type = types.nonEmptyListOf types.nonEmptyStr; default = []; };
    # wg genkey | wg pubkey
    publicKey = mkOption { type = types.nonEmptyStr; };
    wireguardIp = mkOption { type = types.nonEmptyStr; };
    externalIp = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
    lighthouse = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos.services) wireguard;
      inherit (builtins) map toString;
    in mkIf wireguard.enable
    {
      networking =
        let
          # if the host is behind xray, it should listen on another port, to make xray succeffully listen on 51820
          port = 51820 + (if inputs.config.nixos.services.xrayClient.enable then 1 else 0);
        in
        {
          firewall = { allowedUDPPorts = [ port ]; trustedInterfaces = [ "wireguard" ]; };
          wireguard.interfaces.wireguard =
          {
            ips = [ "${wireguard.wireguardIp}/24" ];
            listenPort = port;
            privateKeyFile = inputs.config.sops.secrets."wireguard/privateKey".path;
            peers = map
              (peer:
              {
                publicKey = peer.publicKey;
                allowedIPs = [ (if peer.lighthouse then "192.168.83.0/24" else "${peer.wireguardIp}/32") ];
                endpoint = mkIf (peer.externalIp != null) "${peer.externalIp}:51820";
                persistentKeepalive = 3;
              })
              (map
                (peer: inputs.topInputs.self.nixosConfigurations.${peer}.config.nixos.services.wireguard)
                wireguard.peers);
          };
        };
      sops.secrets."wireguard/privateKey" = {};
    };
}
