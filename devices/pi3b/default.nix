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
            # TODO: reparition
            vfat."/dev/disk/by-uuid/ABC6-6B3E" = "/boot";
            btrfs."/dev/disk/by-uuid/c459c6c0-23a6-4ef2-945a-0bfafa9a45b6" =
              { "/nix/rootfs/current" = "/"; "/nix" = "/nix"; };
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs = {};
        };
        grub.installDevice = "efi";
        networking = { hostname = "pi3b"; networkd = {}; };
        nixpkgs.arch = "aarch64";
        kernel.variant = "nixos";
      };
      services =
      {
        # snapper.enable = true;
        sshd = {};
        xray.client.enable = true;
        fail2ban = {};
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "X5SwWQk3JDT8BDxd04PYXTJi5E20mZKP6PplQ+GDnhI=";
          wireguardIp = "192.168.83.8";
        };
        beesd.instances.root = { device = "/"; hashTableSizeMB = 32; };
      };
    };
  };
}
