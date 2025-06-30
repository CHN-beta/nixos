inputs:
{
  config =
  {
    nixos =
    {
      model.private = true;
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
        network = {};
      };
      hardware.gpu.type = "intel";
      services =
      {
        sshd = {};
        xray = { client.dnsmasq.hosts."git.nas.chn.moe" = "127.0.0.1"; xmuServer = {}; };
        beesd."/".hashTableSizeMB = 10 * 128;
        nfs."/" = [(inputs.topInputs.self.config.dns."chn.moe".getAddress "wg1.pc")];
      };
    };
  };
}
