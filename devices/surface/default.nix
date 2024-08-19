inputs:
{
  imports = (inputs.localLib.mkModules [ inputs.topInputs.nixos-hardware.nixosModules.microsoft-surface-pro-intel ])
    ++ inputs.localLib.findModules ./.;
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
            vfat."/dev/disk/by-uuid/A44C-6DB4" = "/boot";
            btrfs."/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
          };
          decrypt.auto."/dev/disk/by-uuid/124ce605-93b4-454f-924b-fe741f39e065" = { mapper = "root"; ssd = true; };
          swap = [ "/nix/swap/swap" ];
          resume = { device = "/dev/mapper/root"; offset = 533760; };
          rollingRootfs = {};
        };
        nixpkgs.march = "skylake";
        nix = { substituters = [ "https://cache.nixos.org/" "https://nix-store.chn.moe" ]; githubToken.enable = true; };
        kernel = { variant = "xanmod-lts"; patches = [ "surface" "hibernate-progress" ]; };
        networking.hostname = "surface";
        gui.enable = true;
        initrd.unl0kr = {};
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
