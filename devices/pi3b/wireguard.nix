{
  config.nixos.services.wireguard =
  {
    peers = [ "vps6" ];
    publicKey = "X5SwWQk3JDT8BDxd04PYXTJi5E20mZKP6PplQ+GDnhI=";
    wireguardIp = "192.168.83.8";
  };
}
