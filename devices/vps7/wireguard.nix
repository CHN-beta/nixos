{
  config.nixos.services.wireguard =
  {
    peers = [ "vps6" ];
    publicKey = "n056ppNxC9oECcW7wEbALnw8GeW7nrMImtexKWYVUBk=";
    wireguardIp = "192.168.83.2";
    listenIp = "95.111.228.40";
  };
}
