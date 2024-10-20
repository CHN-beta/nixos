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
              "/dev/disk/by-uuid/403fe853-8648-4c16-b2b5-3dfa88aee351"."/boot" = "/boot";
              "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
            };
          };
          luks.manual =
          {
            enable = true;
            devices."/dev/disk/by-uuid/bf7646f9-496c-484e-ada0-30335da57068" = { mapper = "root"; ssd = true; };
            delayedMount = [ "/" ];
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs = {};
        };
        grub.installDevice = "/dev/disk/by-path/pci-0000:00:04.0";
        nixpkgs.march = "znver2";
        nix.substituters = [ "https://nix-store.chn.moe?priority=100" ];
        initrd.sshd.enable = true;
        networking.networkd = {};
        nix-ld = null;
        binfmt = null;
      };
      services =
      {
        snapper.enable = true;
        sshd = {};
        fail2ban = {};
        beesd.instances.root = { device = "/"; hashTableSizeMB = 64; };
        xray.server = { serverName = "xserver.vps4.chn.moe"; userNumber = 4; };
      };
    };
  };
}
