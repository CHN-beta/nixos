inputs:
{
  config =
  {
    nixos =
    {
      model.cluster.nodeType = "master";
      system =
      {
        nixpkgs.march = "znver3";
        network.settings =
        {
          static.enp58s0 = { ip = "192.168.178.1"; mask = 24; };
          trust = [ "enp58s0" ];
          masquerade = [ "enp58s0" ];
        };
        fileSystems =
        {
          swap = [ "/dev/disk/by-partlabel/srv2-node0-swap" ];
          rollingRootfs.waitDevices = builtins.map (n: "/dev/disk/by-partlabel/srv2-node0-root${builtins.toString n}")
            (builtins.genList (n: n + 2) 3);
        };
        kernel.patches = [ "btrfs" ];
      };
      services =
      {
        beesd."/".hashTableSizeMB = 10 * 128;
        hpcstat = {};
        sshd = { groupBanner = true; motd = true; };
        lumericalLicenseManager.macAddress = "04:42:1a:26:0c:07";
      };
    };
    services.hardware.bolt.enable = true;
  };
}
