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
            vfat."/dev/disk/by-uuid/3F57-0EBE" = "/boot/efi";
            btrfs =
            {
              "/dev/disk/by-uuid/02e426ec-cfa2-4a18-b3a5-57ef04d66614"."/" = "/boot";
              "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
            };
          };
          decrypt.auto =
          {
            "/dev/disk/by-uuid/55fdd19f-0f1d-4c37-bd4e-6df44fc31f26" = { mapper = "root"; ssd = true; };
            "/dev/disk/by-uuid/4be45329-a054-4c20-8965-8c5b7ee6b35d" =
              { mapper = "swap"; ssd = true; before = [ "root" ]; };
          };
          swap = [ "/dev/mapper/swap" ];
          resume = "/dev/mapper/swap";
          rollingRootfs = {};
        };
        grub =
        {
          # TODO: install windows
          # windowsEntries = { "7317-1DB6" = "Windows"; "7321-FA9C" = "Windows for malware"; };
          installDevice = "efi";
        };
        nix =
        {
          marches =
          [
            "znver2" "znver3" "znver4"
            # FXSR SAHF XSAVE
            "sandybridge"
            # FXSR PREFETCHW RDRND SAHF
            "silvermont"
            # FXSR HLE LZCNT PREFETCHW RDRND SAHF XSAVE
            "broadwell"
            # FXSR HLE LZCNT PREFETCHW RDRND SAHF SGX XSAVE
            "skylake"
            # AVX-VNNI CLDEMOTE GFNI-SSE HRESET KL LZCNT MOVDIR64B MOVDIRI PCONFIG PREFETCHW PTWRITE RDRND
            # SERIALIZE SGX WAITPKG WIDEKL XSAVE XSAVEOPT
            "alderlake"
          ];
          remote.master = { enable = true; hosts = [ "xmupc1" "xmupc2" ]; };
        };
        nixpkgs =
          { march = "znver4"; cuda = { enable = true; capabilities = [ "8.9" ]; forwardCompat = false; }; };
        kernel = { varient = "cachyos"; patches = [ "cjktty" "hibernate-progress" ]; };
        networking.hostname = "pc";
        sysctl.laptop-mode = 5;
      };
      hardware =
      {
        cpus = [ "amd" ];
        gpu = { type = "amd+nvidia"; prime.busId = { amd = "8:0:0"; nvidia = "1:0:0"; }; dynamicBoost = true; };
        bluetooth.enable = true;
        joystick.enable = true;
        printer.enable = true;
        sound.enable = true;
        legion.enable = true;
      };
      packages.packageSet = "workstation";
      virtualization =
      {
        waydroid.enable = true;
        docker.enable = true;
        kvmHost = { enable = true; gui = true; autoSuspend = [ "win10" "hardconnect" ]; };
        nspawn = [ "arch" "ubuntu-22.04" "fedora" ];
      };
      services =
      {
        snapper.enable = true;
        fontconfig.enable = true;
        samba =
        {
          enable = true;
          private = true;
          hostsAllowed = "192.168. 127.";
          shares =
          {
            media.path = "/run/media/chn";
            home.path = "/home/chn";
            mnt.path = "/mnt";
            share.path = "/home/chn/share";
          };
        };
        sshd.enable = true;
        xray.client = {};
        firewall.trustedInterfaces = [ "virbr0" "waydroid0" ];
        acme = { enable = true; cert."debug.mirism.one" = {}; };
        frpClient =
        {
          enable = true;
          serverName = "frp.chn.moe";
          user = "pc";
          stcpVisitor."yy.vnc".localPort = 6187;
        };
        nix-serve = { enable = true; hostname = "nix-store.chn.moe"; };
        smartd.enable = true;
        misskey.instances.misskey.hostname = "xn--qbtm095lrg0bfka60z.chn.moe";
        beesd = { enable = true; instances.root = { device = "/"; hashTableSizeMB = 4096; threads = 4; }; };
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "l1gFSDCeBxyf/BipXNvoEvVvLqPgdil84nmr5q6+EEw=";
          wireguardIp = "192.168.83.3";
        };
        gamemode = { enable = true; drmDevice = 1; };
        slurm = { enable = true; cpu = { cores = 16; threads = 2; }; memoryMB = 90112; gpus."4060" = 1; };
        xrdp =
        {
          enable = true;
          hostname = [ "pc.chn.moe" ];
        };
      };
      bugs = [ "xmunet" "backlight" "amdpstate" ];
    };
    networking.extraHosts = "74.211.99.69 mirism.one beta.mirism.one ng01.mirism.one";
    services.colord.enable = true;
    virtualisation.virtualbox.host = { enable = true; enableExtensionPack = true; };
    specialisation =
    {
      nvidia.configuration =
      {
        nixos =
        {
          hardware.gpu.type = inputs.lib.mkForce "nvidia";
          services.gamemode.drmDevice = inputs.lib.mkForce 0;
        };
        system.nixos.tags = [ "nvidia" ];
      };
      hybrid-sync.configuration =
      {
        nixos.hardware.gpu.prime.mode = "sync";
        system.nixos.tags = [ "hybrid-sync" ];
      };
      amd.configuration =
      {
        nixos.hardware.gpu = { type = inputs.lib.mkForce "amd"; dynamicBoost = inputs.lib.mkForce false; };
        boot =
        {
          extraModprobeConfig =
          ''
            blacklist nouveau
            options nouveau modeset=0
          '';
          blacklistedKernelModules = [ "nvidia" "nvidia_drm" "nvidia_modeset" ];
        };
        services.udev.extraRules =
        ''
          # Remove NVIDIA USB xHCI Host Controller devices, if present
          ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c0330", ATTR{power/control}="auto", ATTR{remove}="1"
          # Remove NVIDIA USB Type-C UCSI devices, if present
          ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x0c8000", ATTR{power/control}="auto", ATTR{remove}="1"
          # Remove NVIDIA Audio devices, if present
          ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x040300", ATTR{power/control}="auto", ATTR{remove}="1"
          # Remove NVIDIA VGA/3D controller devices
          ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x03[0-9]*", ATTR{power/control}="auto", ATTR{remove}="1"
        '';
        system.nixos.tags = [ "amd" ];
      };
    };
  };
}
