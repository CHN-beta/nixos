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
            btrfs."/dev/mapper/root3" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
          };
          swap = [ "/dev/mapper/swap" ];
          rollingRootfs.waitDevices = [ "/dev/mapper/root4" ];
        };
        initrd.sshd = {};
        nixpkgs.march = "silvermont";
        networking = {};
      };
      hardware = { cpus = [ "intel" ]; gpu.type = "intel"; };
      services =
      {
        sshd = {};
        xray.client =
        {
          enable = true;
          # TODO: remove on next month
          xray =
          {
            serverAddress = inputs.topInputs.self.config.dns."chn.moe".getAddress "xserver.srv3";
            serverName = "xserver.srv3.chn.moe";
          };
          dnsmasq.hosts."git.nas.chn.moe" = "127.0.0.1";
        };
        beesd."/".hashTableSizeMB = 10 * 128;
        nfs."/" = inputs.topInputs.self.config.dns."chn.moe".getAddress "wg1.pc";
        # btrbk = [ "pc" "vps6" "srv3" ];
      };
    };
  };
}
