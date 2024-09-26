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
          eno146 = { ip = "192.168.178.1"; mask = 24; };
        };
        cluster.nodeType = "master";
      };
      services =
      {
        xray.client = { enable = true; dnsmasq.extraInterfaces = [ "eno146" ]; };
        beesd.instances.root = { device = "/"; hashTableSizeMB = 512; threads = 4; };
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "Br+ou+t9M9kMrnNnhTvaZi2oNFRygzebA1NqcHWADWM=";
          wireguardIp = "192.168.83.9";
        };
        nfs = { root = "/"; exports = "/home"; accessLimit = "192.168.178.0/24"; };
      };
      packages.packages._prebuildPackages =
        [ inputs.topInputs.self.nixosConfigurations.srv1-node1.pkgs.localPackages.vasp.intel ];
    };
    # allow other machine access network by this machine
    systemd.network.networks."10-eno146".networkConfig.IPMasquerade = "both";
    # without this, tproxy does not work
    # TODO: why?
    networking.firewall.trustedInterfaces = [ "eno146" ];
  };
}
