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
            vfat."/dev/disk/by-uuid/7179-9C69" = "/boot/efi";
            btrfs =
            {
              "/dev/disk/by-uuid/c6d35075-85fe-4129-aaa8-f436ab85ce43"."/boot" = "/boot";
              "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
            };
          };
          decrypt.auto =
          {
            "/dev/disk/by-uuid/4f7420f9-ea19-4713-b084-2ac8f0a963ac" = { mapper = "root"; ssd = true; };
            "/dev/disk/by-uuid/88bd9d44-928b-40a2-8f3d-6dcd257c4601" =
              { mapper = "swap"; ssd = true; before = [ "root" ]; };
          };
          swap = [ "/dev/mapper/swap" ];
          resume = "/dev/mapper/swap";
          rollingRootfs = {};
        };
        nixpkgs.march = "znver2";
        grub.installDevice = "efi";
        nix = { substituters = [ "https://cache.nixos.org/" "https://nix-store.chn.moe" ]; githubToken.enable = true; };
        kernel.variant = "steamos";
        networking.hostname = "steamdeck";
        gui.enable = true;
        initrd.unl0kr = {};
      };
      hardware = { cpus = [ "amd" ]; gpu.type = "amd"; steamdeck = {}; };
      packages.packageSet = "desktop-extra";
      virtualization = { docker.enable = true; waydroid.enable = true; };
      services =
      {
        snapper.enable = true;
        sshd = {};
        xray.client.enable = true;
        firewall.trustedInterfaces = [ "virbr0" ];
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "j7qEeODVMH31afKUQAmKRGLuqg8Bxd0dIPbo17LHqAo=";
          wireguardIp = "192.168.83.5";
        };
        beesd.instances.root = { device = "/"; hashTableSizeMB = 512; };
      };
      bugs = [ "xmunet" ];
    };
  };
}
