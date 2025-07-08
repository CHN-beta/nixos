inputs:
{
  config =
  {
    nixos =
    {
      system =
      {
        nixpkgs.march = "skylake";
        network =
        {
          static.eno2 = { ip = "192.168.178.1"; mask = 24; gateway = "192.168.178.2"; dns = "192.168.178.2"; };
          wireless = [ "457的5G" ];
          masquerade = [ "eno2" ];
          trust = [ "eno2" ];
        };
        nix.remote.slave = {};
      };
      services =
      {
        xray.client = { dnsmasq = { extraInterfaces = [ "eno2" ]; hosts."hpc.xmu.edu.cn" = "121.192.191.11"; }; };
        beesd."/" = { hashTableSizeMB = 16 * 128; loadAverage = 8; };
        xrdp = { enable = true; hostname = [ "srv2.chn.moe" ]; };
        samba = { hostsAllowed = ""; shares = { home.path = "/home"; root.path = "/"; }; };
        groupshare = {};
        hpcstat = {};
        ollama = {};
        sshd = { groupBanner = true; motd = true; };
      };
    };
  };
}
