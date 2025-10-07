inputs:
{
  config =
  {
    nixos =
    {
      model.cluster.nodeType = "master";
      system =
      {
        nixpkgs.march = "skylake";
        network.settings =
        {
          static.eno2 = { ip = "192.168.178.1"; mask = 24; };
          masquerade = [ "eno2" ];
          trust = [ "eno2" ];
        };
        nix.remote.slave = {};
        fileSystems =
        {
          swap = [ "/dev/disk/by-partlabel/srv2-node0-swap" ];
          mount.btrfs."/dev/disk/by-partlabel/srv2-node0-root1" =
          {
            "/nix/remote/jykang.xmuhpc" = "/data/gpfs01/jykang/.nix";
            "/nix/remote/xmuhk" = "/public/home/xmuhk/.nix";
          };
        };
      };
      services =
      {
        xray.client.dnsmasq = { extraInterfaces = [ "eno1" "eno2" ]; hosts."hpc.xmu.edu.cn" = "121.192.191.11"; };
        beesd."/" = { hashTableSizeMB = 16 * 128; loadAverage = 8; };
        xrdp = { enable = true; hostname = [ "srv2.chn.moe" ]; };
        samba = { hostsAllowed = ""; shares = { home.path = "/home"; root.path = "/"; }; };
        groupshare = {};
        hpcstat = {};
        ollama = {};
        sshd = { groupBanner = true; motd = true; };
        speedtest = {};
        lumericalLicenseManager.macAddress = "70:20:84:09:a3:52";
      };
    };
  };
}
