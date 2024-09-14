inputs:
{
  imports = inputs.localLib.mkModules [ inputs.topInputs.nixos-hardware.nixosModules.microsoft-surface-pro-intel ];
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
            vfat."/dev/disk/by-uuid/4596-D670" = "/boot";
            btrfs."/dev/mapper/root1" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
          };
          decrypt.auto =
          {
            "/dev/disk/by-uuid/eda0042b-ffd5-47d1-b828-4cf99d744c9f" = { mapper = "root1"; ssd = true; };
            "/dev/disk/by-uuid/41d83848-f3dd-4b2f-946f-de1d2ae1cbd4" = { mapper = "swap"; ssd = true; };
          };
          swap = [ "/dev/mapper/swap" ];
          resume = "/dev/mapper/swap";
          rollingRootfs = {};
        };
        nixpkgs.march = "skylake";
        nix = { substituters = [ "https://nix-store.chn.moe?priority=100" ]; githubToken.enable = true; };
        kernel = { variant = "xanmod-lts"; patches = [ "surface" "hibernate-progress" ]; };
        gui.enable = true;
      };
      hardware = { cpus = [ "intel" ]; gpu.type = "intel"; };
      virtualization = { docker.enable = true; waydroid.enable = true; };
      services =
      {
        snapper.enable = true;
        sshd = {};
        xray.client =
        {
          enable = true;
          dnsmasq.hosts = builtins.listToAttrs (builtins.map
            (name: { inherit name; value = "0.0.0.0"; })
            [
              "log-upload.mihoyo.com" "uspider.yuanshen.com" "ys-log-upload.mihoyo.com"
              "dispatchcnglobal.yuanshen.com"
            ]);
        };
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
      bugs = [ "xmunet" "suspend-hibernate-no-platform" ];
      packages.vasp = null;
    };
    powerManagement.resumeCommands = ''${inputs.pkgs.systemd}/bin/systemctl restart iptsd'';
    services.iptsd.config =
    {
      Touch = { DisableOnPalm = true; DisableOnStylus = true; Overshoot = 0.5; };
      Contacts = { Neutral = "Average"; NeutralValue = 10; };
    };
  };
}
