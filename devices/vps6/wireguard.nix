{
  config.nixos.services.wireguard =
  {
    peers = [ "pc" "nas" "vps7" "surface" "xmupc1" "xmupc2" "pi3b" ];
    publicKey = "AVOsYUKQQCvo3ctst3vNi8XSVWo1Wh15066aHh+KpF4=";
    wireguardIp = "192.168.83.1";
    listenIp = "74.211.99.69";
    lighthouse = true;
  };
}
