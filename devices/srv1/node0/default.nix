inputs:
{
  config =
  {
    nixos =
    {
      system.nixpkgs.march = "cascadelake";
      packages.vasp = null;
      services =
      {
        xray.client.enable = true;
        beesd.instances.root = { device = "/"; hashTableSizeMB = 512; threads = 4; };
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "Br+ou+t9M9kMrnNnhTvaZi2oNFRygzebA1NqcHWADWM=";
          wireguardIp = "192.168.83.9";
        };
      };
      system.cluster.nodeType = "master";
    };
  };
}
