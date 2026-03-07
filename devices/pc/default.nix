{ pkgs, ...}:
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
            vfat."/dev/disk/by-partlabel/pc-boot" = "/boot";
            btrfs =
            {
              "/dev/mapper/root1" =
              {
                "/nix/rootfs/current" = "/";
                "/nix/persistent" = "/nix/persistent";
                "/nix/swap" = "/nix/swap";
                "/nix/nodatacow" = "/nix/nodatacow";
                "/nix/rootfs" = "/nix/rootfs";
              };
              "/dev/mapper/tf1" =
              {
                "/nix" = "/nix";
                "/nix/remote/xmuhk" = "/public/home/xmuhk/.nix";
                "/nix/remote/jykang" = "/data/gpfs01/jykang/.nix";
                "/nix/remote/wlin" = "/data/gpfs01/wlin/.nix";
                "/nix/remote/hwang" = "/data/gpfs01/hwang/.nix";
              };
            };
            nfs."nas.ts.chn.moe:/nix/persistent" = { mountPoint = "/nix/remote/nas"; mountBeforeSwitch = false; };
          };
          luks.auto =
          {
            "/dev/disk/by-partlabel/pc-root1" = { mapper = "root1"; ssd = true; };
            "/dev/disk/by-uuid/e6764d00-1132-49bc-b321-9a195ba09ea3".mapper = "tf1";
            "/dev/disk/by-partlabel/pc-tf2" = { mapper = "tf2"; ssd = true; };
          };
          swap = [ "/nix/swap/swap" ];
          resume = { device = "/dev/mapper/root1"; offset = 156901642; };
        };
        grub.windowsEntries."08D3-10DE" = "Windows";
        nix.marches =
        [
          "znver2" "znver3" "znver4" "znver5"
          # FXSR HLE LZCNT PREFETCHW RDRND SAHF XSAVE
          "broadwell"
          # FXSR HLE LZCNT PREFETCHW RDRND SAHF SGX XSAVE
          "skylake" "cascadelake"
          # AVX-VNNI CLDEMOTE GFNI-SSE HRESET KL LZCNT PCONFIG PREFETCHW PTWRITE RDRND
          # SERIALIZE SGX WAITPKG WIDEKL XSAVE XSAVEOPT
          "alderlake"
          # SAHF FXSR XSAVE RDRND LZCNT HLE PREFETCHW SGX PCONFIG
          "icelake-server"
        ];
        nixpkgs = { march = "znver5"; rocm = true; };
        sysctl.laptop-mode = 5;
        kernel = { variant = "cachyos"; patches = [ "btrfs" ]; };
      };
      hardware = { gpu.type = "amd"; asus = {};};
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
        xray.client.coredns =
        {
          hosts = builtins.listToAttrs
          (
            (builtins.map
              (name: { inherit name; value = "144.34.225.59"; })
              [ "mirism.one" "beta.mirism.one" "ng01.mirism.one" "initrd.vps6.chn.moe" ])
          );
          extraInterfaces = [ "wlp194s0" ];
        };
        harmonia = {};
        misskey.instances.misskey.hostname = "xn--qbtm095lrg0bfka60z.chn.moe";
        beesd =
        {
          "/" = { hashTableSizeMB = 2 * 128; loadAverage = 4; };
          "/nix" = { hashTableSizeMB = 128; loadAverage = 4; };
        };
        slurm =
        {
          enable = true;
          master = "pc";
          node.pc =
          {
            name = "pc"; address = "127.0.0.1";
            cpu = { sockets = 2; cores = 8; threads = 2; };
            memoryGB = 80;
          };
          partitions.localhost = [ "pc" ];
          tui.cpuQueues = [{ mpiThreads = 4; openmpThreads = 4; memoryGB = 56; }];
        };
        ollama = {};
        podman = {};
        ananicy = {};
        keyd = {};
        kvm = {};
        mariadb.mountFrom = "nodatacow";
        lumericalLicenseManager.macAddress = "a8:e2:91:52:5f:7c";
        open-webui.ollamaHost = "127.0.0.1";
        howdy = {};
        postgresql.enable = true;
      };
      bugs = [ "amdpstate" ];
      packages = { mathematica = {}; vasp = {}; extra = {}; lumerical = {}; };
      user.users = [ "chn" "lilydjwg" ];
    };
    # 允许kvm读取物理硬盘
    users.users.qemu-libvirtd.extraGroups = [ "disk" ];
    services.colord.enable = true;
    services.udev.extraRules =
    ''
      # 禁止鼠标等在睡眠时唤醒
      ACTION=="add", ATTR{power/wakeup}="disabled"
      # CPU降压
      SUBSYSTEM=="power_supply", KERNEL=="BAT0", ACTION=="*", RUN+="${pkgs.ryzenadj}/bin/ryzenadj --set-coall=0x0fff40"
    '';
    boot.kernelParams =
    [
      # 解决有时蓝牙不能使用的问题
      "mt7925e.disable_aspm=1"
      # 插拔电源和扩展坞不要唤醒电脑
      "acpi.ec_no_wakeup=1"
    ];
    systemd.tmpfiles.rules =
    [
      "w /sys/block/bcache*/bcache/sequential_cutoff - - - - 0"
      "w /sys/block/bcache*/bcache/writeback_percent - - - - 30"
    ];
    # 手写笔
    hardware.opentabletdriver.enable = true;
  };
}
