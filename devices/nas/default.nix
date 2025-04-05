inputs:
{
  config =
  {
    nixos =
    {
      model = { type = "desktop"; private = true; };
      system =
      {
        fileSystems =
        {
          mount =
          {
            vfat."/dev/disk/by-uuid/627D-1FAA" = "/boot";
            btrfs =
            {
              "/dev/mapper/nix"."/nix" = "/nix";
              "/dev/mapper/root3" =
              {
                "/nix/rootfs" = "/nix/rootfs";
                "/nix/persistent" = "/nix/persistent";
                "/nix/nodatacow" = "/nix/nodatacow";
                "/nix/rootfs/current" = "/";
                "/nix/backup" = "/nix/backup";
              };
            };
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs.waitDevices = [ "/dev/mapper/root4" ];
        };
        initrd.sshd = {};
        nixpkgs.march = "silvermont";
        nix.substituters = [ "https://nix-store.chn.moe?priority=100" ];
        networking = { wireless = [ "457" ]; dhcp = [ "wlp0s20u1" ]; };
      };
      hardware = { cpus = [ "intel" ]; gpu.type = "intel"; };
      services =
      {
        sshd = {};
        xray.client = { enable = true; dnsmasq.hosts."git.nas.chn.moe" = "127.0.0.1"; };
        beesd.instances =
        {
          root = { device = "/"; hashTableSizeMB = 10 * 128; threads = 4; };
          nix.device = "/nix";
        };
      };
    };
  };
}
