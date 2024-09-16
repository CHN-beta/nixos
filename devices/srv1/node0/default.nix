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
      };
    };
    services.nfs.server =
    {
      enable = true;
      exports = "/home 192.168.178.0/24(rw,fsid=0)";
    };
    networking =
    {
      firewall.allowedTCPPorts = [ 2049 ];
    };
    systemd.network.networks."10-eno146".networkConfig.IPMasquerade = "both";
  };
}
