inputs:
{
  config =
  {
    nixos =
    {
      system =
      {
        nix.marches = [ "cascadelake" "broadwell" ];
        nixpkgs.march = "cascadelake";
        networking.networkd.static =
        {
          eno145 = { ip = "192.168.1.10"; mask = 24; gateway = "192.168.1.1"; };
          eno146 = { ip = "192.168.178.1"; mask = 24; };
        };
        cluster.nodeType = "master";
      };
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
    };
    services.nfs.server =
    {
      enable = true;
      exports = "/home 192.168.178.0/24(rw)";
    };
    networking.firewall.allowedTCPPorts = [ 2049 ];
  };
}
