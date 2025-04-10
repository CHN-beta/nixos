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
            vfat."/dev/disk/by-uuid/7A60-4232" = "/boot";
            btrfs."/dev/mapper/root1" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
          };
          luks.auto =
          {
            "/dev/disk/by-uuid/4c73288c-bcd8-4a7e-b683-693f9eed2d81" = { mapper = "root1"; ssd = true; };
            "/dev/disk/by-uuid/4be45329-a054-4c20-8965-8c5b7ee6b35d" =
              { mapper = "swap"; ssd = true; before = [ "root1" ]; };
          };
          swap = [ "/dev/mapper/swap" ];
          resume = "/dev/mapper/swap";
          rollingRootfs = {};
        };
        grub.windowsEntries."08D3-10DE" = "Windows";
        nix.marches =
        [
          "znver2" "znver3" "znver4"
          # FXSR SAHF XSAVE
          "sandybridge"
          # FXSR PREFETCHW RDRND SAHF
          "silvermont"
          # FXSR HLE LZCNT PREFETCHW RDRND SAHF XSAVE
          "broadwell"
          # FXSR HLE LZCNT PREFETCHW RDRND SAHF SGX XSAVE
          "skylake" "cascadelake"
          # SAHF FXSR XSAVE RDRND LZCNT HLE PREFETCHW SGX MOVDIRI MOVDIR64B AVX512VP2INTERSECT KEYLOCKER
          "tigerlake"
          # AVX-VNNI CLDEMOTE GFNI-SSE HRESET KL LZCNT MOVDIR64B MOVDIRI PCONFIG PREFETCHW PTWRITE RDRND
          # SERIALIZE SGX WAITPKG WIDEKL XSAVE XSAVEOPT
          "alderlake"
        ];
        nixpkgs = { march = "znver4"; cuda.capabilities = [ "8.9" ]; };
        kernel.variant = "cachyos-lts";
        sysctl.laptop-mode = 5;
      };
      hardware =
      {
        cpus = [ "amd" ];
        gpu = { type = "nvidia"; nvidia = { dynamicBoost = true; driver = "beta"; }; };
        legion = {};
      };
      virtualization =
      {
        kvmHost = { enable = true; gui = true; };
        nspawn = [ "arch" "ubuntu-22.04" "fedora" ];
      };
      services =
      {
        samba =
        {
          hostsAllowed = "192.168. 127.";
          shares =
          {
            media.path = "/run/media/chn";
            home.path = "/home/chn";
            mnt.path = "/mnt";
            share.path = "/home/chn/share";
          };
        };
        sshd = {};
        xray.client =
        {
          enable = true;
          dnsmasq.hosts = builtins.listToAttrs
          (
            (builtins.map
              (name: { inherit name; value = "144.34.225.59"; })
              [ "mirism.one" "beta.mirism.one" "ng01.mirism.one" "initrd.vps6.chn.moe" ])
            ++ (builtins.map
              (name: { inherit name; value = "0.0.0.0"; })
              [ "log-upload.mihoyo.com" "uspider.yuanshen.com" "ys-log-upload.mihoyo.com" ])
          )
          // {
            "4006024680.com" = "192.168.199.1";
            "hpc.xmu.edu.cn" = "121.192.191.11";
          };
        };
        acme.cert."debug.mirism.one" = {};
        frpClient =
        {
          enable = true;
          serverName = "frp.chn.moe";
          user = "pc";
          stcpVisitor =
          {
            "yy.vnc".localPort = 6187;
            "temp.ssh".localPort = 6188;
          };
        };
        nix-serve = { enable = true; hostname = "nix-store.chn.moe"; };
        misskey.instances.misskey.hostname = "xn--qbtm095lrg0bfka60z.chn.moe";
        beesd.instances.root = { device = "/"; hashTableSizeMB = 4 * 128; threads = 4; };
        gamemode = { enable = true; drmDevice = 0; };
        slurm =
        {
          enable = true;
          master = "pc";
          node.pc =
          {
            name = "pc"; address = "127.0.0.1";
            cpu = { sockets = 2; cores = 8; threads = 2; };
            memoryGB = 80;
            gpus."4060" = 1;
          };
          partitions.localhost = [ "pc" ];
          tui =
          {
            cpuQueues = [{ mpiThreads = 4; openmpThreads = 4; memoryGB = 56; }];
            gpuQueues = [{ name = "localhost"; gpuIds = [ "4060" ]; }];
          };
        };
        ollama = {};
        docker = {};
        ananicy = {};
        keyd = {};
        lumericalLicenseManager = {};
      };
      bugs = [ "xmunet" "backlight" "amdpstate" "iwlwifi" ];
      packages = { android-studio = {}; mathematica = {}; };
    };
    boot.loader.grub =
    {
      extraFiles =
      {
        "DisplayEngine.efi" = ./bios/DisplayEngine.efi;
        "SetupBrowser.efi" = ./bios/SetupBrowser.efi;
        "UiApp.efi" = ./bios/UiApp.efi;
        "EFI/Boot/Bootx64.efi" = ./bios/Bootx64.efi;
        "nixos.iso" = inputs.topInputs.self.src.iso;
      };
      extraEntries = 
      ''
        menuentry 'Advanced UEFI Firmware Settings' {
          insmod fat
          insmod chain
          chainloader @bootRoot@/EFI/Boot/Bootx64.efi
        }
        menuentry 'Live ISO' {
          set iso_path=@bootRoot@/nixos.iso
          export iso_path
          search --set=root --file "$iso_path"
          loopback loop "$iso_path"
          root=(loop)
          configfile /boot/grub/loopback.cfg
          loopback --delete loop
        }
      '';
    };
    # 禁止鼠标等在睡眠时唤醒
    services.udev.extraRules = ''ACTION=="add", ATTR{power/wakeup}="disabled"'';
    # 允许kvm读取物理硬盘
    users.users.qemu-libvirtd.extraGroups = [ "disk" ];
    networking.extraHosts = "144.34.225.59 mirism.one beta.mirism.one ng01.mirism.one";
    services.colord.enable = true;
  };
}
