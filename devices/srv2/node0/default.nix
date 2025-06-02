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
          masquerade = [ "eno2" ];
          trust = [ "eno2" ];
        };
      };
      services =
      {
        xray.client =
        {
          enable = true;
          dnsmasq = { extraInterfaces = [ "eno2" ]; hosts."hpc.xmu.edu.cn" = "121.192.191.11"; };
        };
        beesd."/" = { hashTableSizeMB = 16 * 128; loadAverage = 8; };
        samba = { hostsAllowed = ""; shares = { home.path = "/home"; root.path = "/"; }; };
        groupshare = {};
        hpcstat = {};
        ollama = {};
      };
    };
  };
}
