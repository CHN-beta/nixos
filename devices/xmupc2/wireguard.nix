{
  config.nixos.services.wireguard =
  {
    peers = [ "vps6" ];
    publicKey = "lNTwQqaR0w/loeG3Fh5qzQevuAVXhKXgiPt6fZoBGFE=";
    wireguardIp = "192.168.83.7";
  };
}
