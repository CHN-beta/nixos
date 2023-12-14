inputs:
{
  options.nixos.services.wireguard = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    peers = mkOption { type = types.nonEmptyListOf types.nonEmptyStr; default = []; };
    _peer = mkOption
    {
      type = types.attrsOf (types.submodule { options =
      {
        publicKey = mkOption { type = types.nonEmptyStr; };
        wireguardIp = mkOption { type = types.nonEmptyStr; };
        externalIp = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
        lighthouse = mkOption { type = types.bool; default = false; };
      };});
      readOnly = true;
      default = # wg genkey | wg pubkey
      {
        vps6 =
        {
          publicKey = "AVOsYUKQQCvo3ctst3vNi8XSVWo1Wh15066aHh+KpF4=";
          wireguardIp = "192.168.83.1";
          externalIp = "74.211.99.69";
          lighthouse = true;
        };
        vps7 =
        {
          publicKey = "n056ppNxC9oECcW7wEbALnw8GeW7nrMImtexKWYVUBk=";
          wireguardIp = "192.168.83.2";
          externalIp = "95.111.228.40";
        };
        pc = { publicKey = "l1gFSDCeBxyf/BipXNvoEvVvLqPgdil84nmr5q6+EEw="; wireguardIp = "192.168.83.3"; };
        nas = { publicKey = "xCYRbZEaGloMk7Awr00UR3JcDJy4AzVp4QvGNoyEgFY="; wireguardIp = "192.168.83.4"; };
        xmupc1 = { publicKey = "JEY7D4ANfTpevjXNvGDYO6aGwtBGRXsf/iwNwjwDRQk="; wireguardIp = "192.168.83.5"; };
      };
    };
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
          self = wireguard._peer.${inputs.config.nixos.system.networking.hostname};
          # if the host is behind xray, it should listen on another port, to make xray succeffully listen on 51820
          port = 51820 + (if inputs.config.nixos.services.xrayClient.enable then 1 else 0);
        in
        {
          firewall = { allowedUDPPorts = [ (toString port) ]; trustedInterfaces = [ "wireguard" ]; };
          wireguard.interfaces.wireguard =
          {
            ips = [ "${self.wireguardIp}/24" ];
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
              (map (peer: wireguard._peer.${peer}) wireguard.peers);
          };
        };
      sops.secrets."wireguard/privateKey" = {};
    };
}
