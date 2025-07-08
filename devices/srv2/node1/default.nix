inputs:
{
  config =
  {
    nixos =
    {
      model.cluster.nodeType = "master";
      system =
      {
        fileSystems.mount.btrfs."/dev/disk/by-partlabel/srv2-node1-data1" =
          { "/nix/persistent" = "/nix/persistent"; "/nix/nodatacow" = "/nix/nodatacow"; };
        nixpkgs.march = "znver3";
        network =
        {
          static.enp58s0 = { ip = "192.168.178.2"; mask = 24; };
          trust = [ "enp58s0" ];
          wireless = [ "457的5G" ];
          masquerade = [ "enp58s0" ];
        };
      };
      services =
      {
        xray.client.dnsmasq.extraInterfaces = [ "enp58s0" ];
        beesd = { "/".loadAverage = 8; "/nix/persistent" = { hashTableSizeMB = 128 * 10; loadAverage = 8; }; };
        xrdp = { enable = true; hostname = [ "srv2.chn.moe" ]; };
        samba = { hostsAllowed = ""; shares = { home.path = "/home"; root.path = "/"; }; };
        groupshare = {};
        hpcstat = {};
        sshd = { groupBanner = true; motd = true; };
      };
    };
    services.hardware.bolt.enable = true;
  };
}
