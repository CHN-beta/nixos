{
  config.nixos.services.wireguard =
  {
    peers = [ "vps6" ];
    publicKey = "l1gFSDCeBxyf/BipXNvoEvVvLqPgdil84nmr5q6+EEw=";
    wireguardIp = "192.168.83.3";
  };
}
