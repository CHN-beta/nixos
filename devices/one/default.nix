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
            vfat."/dev/disk/by-partlabel/one-boot" = "/boot";
            btrfs."/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
          };
          luks.auto."/dev/disk/by-partlabel/one-root" = { mapper = "root"; ssd = true; };
          swap = [ "/nix/swap/swap" ];
          resume = { device = "/dev/mapper/root"; offset = 728784; };
          rollingRootfs = {};
        };
        nixpkgs.march = "tigerlake";
      };
      hardware = { cpus = [ "intel" ]; gpu.type = "intel"; };
      services =
      {
        snapper.enable = true;
        xray.client.enable = true;
        smartd.enable = true;
        beesd.instances.root = { device = "/"; hashTableSizeMB = 512; };
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "Hey9V9lleafneEJwTLPaTV11wbzCQF34Cnhr0w2ihDQ=";
          wireguardIp = "192.168.83.5";
        };
        sshd = {};
      };
      bugs = [ "xmunet" ];
    };
    boot.kernelParams = [ "acpi_osi=!" ''acpi_osi="Windows 2015"'' ];
    security =
    {
      pam.services.kde.rules.auth.pass =
        { modulePath = "pam_succeed_if.so"; args = [ "user" "=" "chn" ]; control = "sufficient"; order = 0; };
      sudo.wheelNeedsPassword = false;
    };
  };
}
