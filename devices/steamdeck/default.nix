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
            vfat."/dev/disk/by-uuid/A44C-6DB4" = "/boot/efi";
            btrfs =
            {
              "/dev/disk/by-uuid/10c2ee85-b5bf-41ff-9901-d36d2edd8a69"."/boot" = "/boot";
              "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
            };
          };
          decrypt.auto."/dev/disk/by-uuid/124ce605-93b4-454f-924b-fe741f39e065" = { mapper = "root"; ssd = true; };
          swap = [ "/nix/swap/swap" ];
          resume = { device = "/dev/mapper/root"; offset = 533760; };
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
