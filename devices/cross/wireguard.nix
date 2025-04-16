inputs:
let
  devices =
  {
    vps6 = { publicKey = "AVOsYUKQQCvo3ctst3vNi8XSVWo1Wh15066aHh+KpF4="; wireguardIp = 1; };
    vps7 = { publicKey = "n056ppNxC9oECcW7wEbALnw8GeW7nrMImtexKWYVUBk="; wireguardIp = 2; };
    pc = { publicKey = "l1gFSDCeBxyf/BipXNvoEvVvLqPgdil84nmr5q6+EEw="; wireguardIp = 3; };
    nas = { publicKey = "xCYRbZEaGloMk7Awr00UR3JcDJy4AzVp4QvGNoyEgFY="; wireguardIp = 4; };
    one = { publicKey = "Hey9V9lleafneEJwTLPaTV11wbzCQF34Cnhr0w2ihDQ="; wireguardIp = 5; };
    srv1-node0 = { publicKey = "Br+ou+t9M9kMrnNnhTvaZi2oNFRygzebA1NqcHWADWM="; wireguardIp = 9; };
    srv1-node1 = { publicKey = "wyNONnJF2WHykaHsQIV4gNntOaCsdTfi7ysXDsR2Bww="; wireguardIp = 6; };
    srv1-node2 = { publicKey = "zWvkVyJwtQhwmxM2fHwNDnK+iwYm1O0RHrwCQ/VXdEo="; wireguardIp = 8; };
    srv2-node0 = { publicKey = "lNTwQqaR0w/loeG3Fh5qzQevuAVXhKXgiPt6fZoBGFE="; wireguardIp = 7; };
    srv2-node1 = { publicKey = "wc+DkY/WlGkLeI8cMcoRHcCcITNqX26P1v5JlkQwWSc="; wireguardIp = 10; };
  };
  networks = # 对于每个网络，只需要设置 net，每个设备的 listenPort，以及每个设备的每个 peer 的 publicKey endpoint allowedIPs
  {
    # 星形网络，所有流量通过 vps6 中转
    wg0 = let net = 83; vps6ListenIp = "144.34.225.59"; in
    {
      inherit net;
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
                inherit (devices.${peerName}) publicKey;
                allowedIPs =
                  [ "192.168.${builtins.toString net}.${builtins.toString devices.${peerName}.wireguardIp}" ];
              };
            })
            (inputs.lib.remove "vps6" (builtins.attrNames devices)));
        };
      }
      // (builtins.listToAttrs (builtins.map
        (deviceName:
        {
          name = deviceName;
          value.peer.vps6 =
          {
            inherit (devices.vps6) publicKey;
            endpoint = "${vps6ListenIp}:51820";
            allowedIPs = [ "192.168.${builtins.toString net}.0/24" ];
          };
        })
        (inputs.lib.remove "vps6" (builtins.attrNames devices))));
    };
    # 两两互连
    wg1 =
      let
        net = 84;
        listenIps = let office = "210.34.16.60";
          in { "srv1-node0" = "59.77.36.250"; "srv2-node0" = office; pc = office; nas = office; };
      in
      {
        inherit net;
        devices = builtins.listToAttrs (builtins.map
          (deviceName:
          {
            name = deviceName;
            value =
            {
              listenPort = 51820 + devices.${deviceName}.wireguardIp;
              peer = builtins.listToAttrs (builtins.map
                (peerName:
                {
                  name = peerName;
                  value = let inherit (devices.${peerName}) wireguardIp; in
                  {
                    inherit (devices.${peerName}) publicKey;
                    endpoint = "${listenIps.${peerName}}:${builtins.toString (51820 + wireguardIp)}";
                    allowedIPs = [ "192.168.${builtins.toString net}.${builtins.toString wireguardIp}" ];
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
          ip = "192.168.${builtins.toString network.value.net}.${builtins.toString devices.${hostname}.wireguardIp}";
        };})
    (inputs.localLib.attrsToList networks));
}
