inputs:
{
  config =
  {
    nixos =
    {
      model.cluster.nodeType = "master";
      hardware.cpus = [ "intel" ];
      system =
      {
        nixpkgs.march = "skylake";
        networking =
        {
          static.eno2 = { ip = "192.168.178.1"; mask = 24; };
          wireless = [ "457的5G" ];
        };
      };
      services =
      {
        xray.client = { enable = true; dnsmasq.extraInterfaces = [ "eno2" ]; };
        beesd.instances.root = { device = "/"; hashTableSizeMB = 16384; loadAverage = 8;  };
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "lNTwQqaR0w/loeG3Fh5qzQevuAVXhKXgiPt6fZoBGFE=";
          wireguardIp = "192.168.83.7";
        };
        xrdp = { enable = true; hostname = [ "srv2.chn.moe" ]; };
        samba = { enable = true; hostsAllowed = ""; shares = { home.path = "/home"; root.path = "/"; }; };
        groupshare = {};
        hpcstat = {};
      };
    };
    # allow other machine access network by this machine
    systemd.network.networks."10-eno2".networkConfig.IPMasquerade = "both";
    # without this, tproxy does not work
    networking.firewall.trustedInterfaces = [ "eno2" ];
  };
}
