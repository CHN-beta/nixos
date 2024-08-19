{
  config.nixos.services.wireguard =
  {
    peers = [ "vps6" ];
    publicKey = "xCYRbZEaGloMk7Awr00UR3JcDJy4AzVp4QvGNoyEgFY=";
    wireguardIp = "192.168.83.4";
  };
}
