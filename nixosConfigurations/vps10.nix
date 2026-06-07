{
  config = {
    nixos = {
      system = {
        fileSystems = {
          mount = {
            btrfs = {
              "/dev/disk/by-partlabel/vps10-boot"."/boot" = "/boot";
              "/dev/mapper/root" = {
                "/nix" = "/nix";
                "/nix/rootfs/current" = "/";
              };
            };
          };
          swap = [ "/nix/swap/swap" ];
          luks."/dev/disk/by-partlabel/vps10-root" = {
            mapper = "root";
            ssd = true;
          };
        };
        grub.installDevice = "/dev/disk/by-path/pci-0000:09:01.0-scsi-0:0:0:0";
        initrd.sshd = { };
        nixpkgs.march = "x86-64-v3";
      };
      services = {
        sshd = { };
        fail2ban = { };
      };
    };
  };
}
