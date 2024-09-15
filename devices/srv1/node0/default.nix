inputs:
{
  config =
  {
    nixos =
    {
      system =
      {
        nixpkgs.march = "cascadelake";
        networking.networkd.static =
        {
          eno145 = { ip = "192.168.1.10"; mask = 24; gateway = "192.168.1.1"; };
          eno146 = { ip = "192.168.178.10"; mask = 24; };
        };
      };
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
        slurm =
        {
          enable = true;
          cpu = { sockets = 4; cores = 20; threads = 2; mpiThreads = 8; openmpThreads = 10; };
          memoryMB = 122880;
        };
      };
      system.cluster.nodeType = "master";
    };
  };
}
