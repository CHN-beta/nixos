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
        # TODO: configure network
        # networking.static =
        # {
        #   eno145 = { ip = "192.168.1.10"; mask = 24; gateway = "192.168.1.1"; };
        #   eno146 = { ip = "192.168.178.1"; mask = 24; };
        # };
      };
      services =
      {
        xray.client = { enable = true; dnsmasq.extraInterfaces = [ "eno146" ]; };  # TODO: listen on shared port
        beesd.instances.root = { device = "/"; hashTableSizeMB = 16384; threads = 4; };
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "lNTwQqaR0w/loeG3Fh5qzQevuAVXhKXgiPt6fZoBGFE=";
          wireguardIp = "192.168.83.7";
        };
        xrdp = { enable = true; hostname = [ "srv2.chn.moe" ]; };
        samba = { enable = true; hostsAllowed = ""; shares = { home.path = "/home"; root.path = "/"; }; };
        nfs = { root = "/"; exports = [ "/home" ]; accessLimit = "192.168.178.0/24"; };
        groupshare = {};
        hpcstat = {};
      };
    };
    # TODO: these netowrk settings should be changed
    # allow other machine access network by this machine
    systemd.network.networks."10-eno146".networkConfig.IPMasquerade = "both";
    # without this, tproxy does not work
    # TODO: why?
    networking.firewall.trustedInterfaces = [ "eno146" ];
  };
}
