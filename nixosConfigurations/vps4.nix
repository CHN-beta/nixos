{
  config = {
    nixos = {
      system = {
        fileSystems = {
          mount = {
            btrfs = {
              "/dev/disk/by-uuid/403fe853-8648-4c16-b2b5-3dfa88aee351"."/boot" = "/boot";
              "/dev/mapper/root" = {
                "/nix" = "/nix";
                "/nix/rootfs/current" = "/";
              };
            };
          };
          swap = [ "/nix/swap/swap" ];
          luks."/dev/disk/by-uuid/bf7646f9-496c-484e-ada0-30335da57068" = {
            mapper = "root";
            ssd = true;
          };
        };
        grub.installDevice = "/dev/disk/by-path/pci-0000:00:04.0";
        nixpkgs.march = "znver2";
        initrd.sshd = { };
        network.settings.dhcp = [ "ens3" ];
      };
      services = {
        sshd = { };
        fail2ban = { };
        gatus = { };
      };
    };
  };
}
