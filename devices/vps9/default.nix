inputs:
{
  config =
  {
    nixos =
    {
      system =
      {
        fileSystems =
        {
          mount =
          {
            btrfs =
            {
              "/dev/disk/by-partlabel/vps9-boot"."/boot" = "/boot";
              "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
            };
          };
          swap = [ "/nix/swap/swap" ];
        };
        # TODO: use by-path after install
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
