inputs:
let
  publicKey =
  {
    vps6 = "AVOsYUKQQCvo3ctst3vNi8XSVWo1Wh15066aHh+KpF4=";
    vps7 = "n056ppNxC9oECcW7wEbALnw8GeW7nrMImtexKWYVUBk=";
    pc = "l1gFSDCeBxyf/BipXNvoEvVvLqPgdil84nmr5q6+EEw=";
    nas = "xCYRbZEaGloMk7Awr00UR3JcDJy4AzVp4QvGNoyEgFY=";
    one = "Hey9V9lleafneEJwTLPaTV11wbzCQF34Cnhr0w2ihDQ=";
    srv1-node0 = "Br+ou+t9M9kMrnNnhTvaZi2oNFRygzebA1NqcHWADWM=";
    srv1-node1 = "wyNONnJF2WHykaHsQIV4gNntOaCsdTfi7ysXDsR2Bww=";
    srv1-node2 = "zWvkVyJwtQhwmxM2fHwNDnK+iwYm1O0RHrwCQ/VXdEo=";
    srv2-node0 = "lNTwQqaR0w/loeG3Fh5qzQevuAVXhKXgiPt6fZoBGFE=";
    srv2-node1 = "wc+DkY/WlGkLeI8cMcoRHcCcITNqX26P1v5JlkQwWSc=";
    srv3 = "a1pUi12SN6fIFiHA9W0N1ycuSz1fWUSpZnjz20OPaBk=";
  };
  dns = inputs.topInputs.self.config.dns.wireguard;
  networks = # 对于每个网络，只需要设置 net，每个设备的 listenPort，以及每个设备的每个 peer 的 publicKey endpoint allowedIPs
  {
    # 星形网络，所有流量通过 vps6 中转
    wg0 = let vps6ListenIp = "144.34.225.59"; in
    {
      devices =
      {
        vps6 =
        {
          listenPort = 51820;
          peer = builtins.listToAttrs (builtins.map
            (peerName:
            {
              name = peerName;
              value =
              {
                publicKey = publicKey.${peerName};
                allowedIPs = [ "192.168.${builtins.toString dns.net.wg0}.${builtins.toString dns.peer.${peerName}}" ];
              };
            })
            (inputs.lib.remove "vps6" (builtins.attrNames publicKey)));
        };
      }
      // (builtins.listToAttrs (builtins.map
        (deviceName:
        {
          name = deviceName;
          value.peer.vps6 =
          {
            publicKey = publicKey.vps6;
            endpoint = "${vps6ListenIp}:51820";
            allowedIPs = [ "192.168.${builtins.toString dns.net.wg0}.0/24" ];
          };
        })
        (inputs.lib.remove "vps6" (builtins.attrNames publicKey))));
    };
    # 两两互连
    wg1 =
      let listenIps =
        let office = "210.34.16.60";
        in { "srv1-node0" = "59.77.36.250"; "srv2-node0" = office; pc = office; nas = office; };
      in
      {
        devices = builtins.listToAttrs (builtins.map
          (deviceName:
          {
            name = deviceName;
            value =
            {
              listenPort = 51820 + dns.peer.${deviceName};
              peer = builtins.listToAttrs (builtins.map
                (peerName:
                {
                  name = peerName;
                  value =
                  {
                    publicKey = publicKey.${peerName};
                    endpoint = "${listenIps.${peerName}}:${builtins.toString (51820 + dns.peer.${peerName})}";
                    allowedIPs =
                      [ "192.168.${builtins.toString dns.net.wg1}.${builtins.toString dns.peer.${peerName}}" ];
                  };
                })
                (inputs.lib.remove deviceName (builtins.attrNames listenIps)));
            };
          })
          (builtins.attrNames listenIps));
      };
  };
in
{
  config.nixos.services.wireguard = inputs.lib.mkMerge (builtins.map
    (network:
      let inherit (inputs.config.nixos.model) hostname;
      in inputs.lib.optionalAttrs (network.value.devices ? ${hostname}) { ${network.name} =
        network.value.devices.${hostname}
        // {
          ip = "192.168.${builtins.toString dns.net.${network.name}}.${builtins.toString dns.peer.${hostname}}";
        };})
    (inputs.localLib.attrsToList networks));
}
