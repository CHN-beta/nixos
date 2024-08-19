{
  config.nixos.services.wireguard =
  {
    peers = [ "vps6" ];
    publicKey = "JEY7D4ANfTpevjXNvGDYO6aGwtBGRXsf/iwNwjwDRQk=";
    wireguardIp = "192.168.83.6";
  };
}
