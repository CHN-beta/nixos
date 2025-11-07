inputs:
{
  config =
  {
    nixos =
    {
      system =
      {
        # TODO: use uuid after udev works
        fileSystems =
        {
          mount =
          {
            btrfs =
            {
              "/dev/disk/vda1"."/boot" = "/boot";
              "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
            };
          };
          swap = [ "/nix/swap/swap" ];
        };
        grub.installDevice = "/dev/vda";
        nixpkgs.march = "znver3";
        initrd.sshd = {};
      };
      services =
      {
        sshd = {};
        fail2ban = {};
        xray.server.serverName = "xserver2.vps9.chn.moe";
      };
    };
  };
}
