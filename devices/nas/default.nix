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
            vfat."/dev/disk/by-partlabel/nas-boot" = "/boot";
            btrfs."/dev/mapper/root1" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
          };
          swap = [ "/dev/mapper/swap" ];
          rollingRootfs.waitDevices = [ "/dev/mapper/root2" ];
        };
        initrd.sshd = {};
        nixpkgs.march = "alderlake";
        network = {};
        kernel.patches = [ "btrfs" ];
        nix-ld = null;
      };
      hardware.gpu.type = "intel";
      services =
      {
        sshd = {};
        xray =
        {
          client.dnsmasq = { extraInterfaces = [ "enp3s0" ]; hosts."git.nas.chn.moe" = "127.0.0.1"; };
          xmuServer = {};
          server.serverName = "xservernas.chn.moe";
        };
        beesd."/" = { hashTableSizeMB = 10 * 128; threads = 4; };
        nfs."/" = [(inputs.topInputs.self.config.dns."chn.moe".getAddress "wg1.pc")];
        nix-serve.hostname = "nix-store.nas.chn.moe";
      };
    };
  };
}
