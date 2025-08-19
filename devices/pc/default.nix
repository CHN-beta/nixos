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
            btrfs."/dev/mapper/root1" =
            {
              "/nix" = "/nix";
              "/nix/rootfs/current" = "/";
              "/nix/remote/jykang.xmuhpc" = "/data/gpfs01/jykang/.nix";
              "/nix/remote/xmuhk" = "/public/home/xmuhk/.nix";
            };
            nfs."${inputs.topInputs.self.config.dns."chn.moe".getAddress "wg1.nas"}:/" =
              { mountPoint = "/nix/remote/nas"; hard = false; };
          };
          luks.auto =
          {
            "/dev/disk/by-uuid/pc-root1" = { mapper = "root1"; ssd = true; };
            "/dev/disk/by-uuid/pc-swap" = { mapper = "swap"; ssd = true; before = [ "root1" ]; };
          };
          swap = [ "/dev/mapper/swap" ];
        };
        grub.windowsEntries."08D3-10DE" = "Windows";
        nix =
        {
          marches =
          [
            "znver2" "znver3" "znver5"
            # FXSR PREFETCHW RDRND SAHF
            "silvermont"
            # SAHF FXSR XSAVE RDRND LZCNT HLE
            "haswell"
            # FXSR HLE LZCNT PREFETCHW RDRND SAHF XSAVE
            "broadwell"
            # FXSR HLE LZCNT PREFETCHW RDRND SAHF SGX XSAVE
            "skylake" "cascadelake"
          ];
          remote.master.host.srv2-node0 = [ "skylake" ];
        };
        nixpkgs.march = "znver5";
        sysctl.laptop-mode = 5;
      };
      hardware.gpu.type = "amd";
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
        xray = 
        {
          client.dnsmasq.hosts = builtins.listToAttrs
          (
            (builtins.map
              (name: { inherit name; value = "144.34.225.59"; })
              [ "mirism.one" "beta.mirism.one" "ng01.mirism.one" "initrd.vps6.chn.moe" ])
          )
          // { "4006024680.com" = "192.168.199.1"; };
          xmuClient = {};
        };
        nix-serve = {};
        misskey.instances.misskey.hostname = "xn--qbtm095lrg0bfka60z.chn.moe";
        beesd."/" = { hashTableSizeMB = 4 * 128; threads = 4; };
        slurm =
        {
          enable = true;
          master = "pc";
          node.pc =
          {
            name = "pc"; address = "127.0.0.1";
            cpu = { sockets = 2; cores = 8; threads = 2; };
            memoryGB = 32;
          };
          partitions.localhost = [ "pc" ];
          tui.cpuQueues = [{ mpiThreads = 4; openmpThreads = 4; memoryGB = 32; }];
        };
        ollama = {};
        podman = {};
        ananicy = {};
        keyd = {};
        kvm.aarch64 = true;
        nfs."/" = [ "192.168.84.0/24" ];
      };
      bugs = [ "xmunet" "amdpstate" "iwlwifi" ];
      packages = { mathematica = {}; vasp = {}; };
    };
    boot.loader.grub =
    {
      extraFiles."nixos.iso" = inputs.topInputs.self.src.iso.nixos;
      extraEntries = 
      ''
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
    services.colord.enable = true;
  };
}
