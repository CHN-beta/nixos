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
        fileSystems.swap = [ "/dev/disk/by-partlabel/srv2-node0-swap" ];
        kernel.patches = [ "btrfs" ];
      };
      services =
      {
        xray.client.dnsmasq.extraInterfaces = [ "enp58s0" ];
        beesd."/".hashTableSizeMB = 10 * 128;
        hpcstat = {};
        sshd = { groupBanner = true; motd = true; };
        lumericalLicenseManager.macAddress = "70:20:84:09:a3:52";
      };
    };
    services.hardware.bolt.enable = true;
  };
}
