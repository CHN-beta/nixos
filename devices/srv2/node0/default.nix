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
        xray.client =
          { enable = true; dnsmasq = { extraInterfaces = [ "eno2" ]; hosts."hpc.xmu.edu.cn" = "121.192.191.11"; }; };
        beesd.instances.root = { device = "/"; hashTableSizeMB = 16 * 128; loadAverage = 8; };
        xrdp = { enable = true; hostname = [ "srv2.chn.moe" ]; };
        samba = { hostsAllowed = ""; shares = { home.path = "/home"; root.path = "/"; }; };
        groupshare = {};
        hpcstat = {};
        ollama = {};
      };
    };
    # allow other machine access network by this machine
    systemd.network.networks."10-eno2".networkConfig.IPMasquerade = "both";
    # without this, tproxy does not work
    networking.firewall.trustedInterfaces = [ "eno2" ];
  };
}
