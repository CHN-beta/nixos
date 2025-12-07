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
            vfat."/dev/disk/by-partlabel/pc-boot" = "/boot";
            btrfs =
            {
              "/dev/mapper/root1" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
              "/dev/mapper/tf1"."/" = "/nix/tf";
            };
          };
          luks.auto =
          {
            "/dev/disk/by-partlabel/pc-root1" = { mapper = "root1"; ssd = true; };
            "/dev/disk/by-partlabel/pc-tf1" = { mapper = "tf1"; ssd = true; };
          };
          swap = [ "/nix/swap/swap" ];
          resume = { device = "/dev/mapper/root1"; offset = 131605760; };
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
        kernel.variant = "cachyos";
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
        xray.client.dnsmasq =
        {
          hosts = builtins.listToAttrs
          (
            (builtins.map
              (name: { inherit name; value = "144.34.225.59"; })
              [ "mirism.one" "beta.mirism.one" "ng01.mirism.one" "initrd.vps6.chn.moe" ])
          );
          extraInterfaces = [ "wlo1" ];
        };
        harmonia.store = "/nix/tf/nix/store";
        beesd = { "/".hashTableSizeMB = 2 * 128; "/nix/tf".hashTableSizeMB = 128; };
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
        open-webui.ollamaHost = "127.0.0.1";
        howdy = {};
      };
      bugs = [ "amdpstate" ];
      packages = { mathematica = {}; vasp = {}; };
      user.users = [ "chn" "lilydjwg" ];
    };
    # 允许kvm读取物理硬盘
    users.users.qemu-libvirtd.extraGroups = [ "disk" ];
    services.colord.enable = true;
    services.udev.extraRules =
    ''
      # CPU降压
      SUBSYSTEM=="power_supply", KERNEL=="BAT0", ACTION=="*", RUN+="${inputs.pkgs.ryzenadj}/bin/ryzenadj --set-coall=0x0fff20"
    '';
    # 解决有时蓝牙不能使用的问题
    boot.kernelParams = [ "mt7925e.disable_aspm=1" ];
  };
}
