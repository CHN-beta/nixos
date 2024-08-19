{
  config.nixos.services.wireguard =
  {
    peers = [ "vps6" ];
    publicKey = "j7qEeODVMH31afKUQAmKRGLuqg8Bxd0dIPbo17LHqAo=";
    wireguardIp = "192.168.83.5";
  };
}
