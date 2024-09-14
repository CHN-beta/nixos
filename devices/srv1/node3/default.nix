inputs:
{
  config =
  {
    nixos =
    {
      system =
      {
        fileSystems.mount =
        {
          vfat."/dev/disk/by-uuid/7A60-4232" = "/boot";
          btrfs."/dev/mapper/root1" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
        };
        nixpkgs.march = "cascadelake";
      };
      packages.vasp = null;
      services =
      {
        xray.client.enable = true;
        beesd.instances.root = { device = "/"; hashTableSizeMB = 4096; threads = 4; };
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "l1gFSDCeBxyf/BipXNvoEvVvLqPgdil84nmr5q6+EEw=";
          wireguardIp = "192.168.83.3";
        };
      };
    };
  };
}
