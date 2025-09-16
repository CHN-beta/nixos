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
            btrfs."/dev/mapper/root1" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
          };
          luks.auto."/dev/disk/by-partlabel/pc-root1" = { mapper = "root1"; ssd = true; };
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
        ];
        # nixpkgs.march = "znver4";
        sysctl.laptop-mode = 5;
        kernel.variant = "xanmod-latest";
      };
      hardware = { gpu.type = "amd"; cpu = "amd"; };
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
            memoryGB = 80;
          };
          partitions.localhost = [ "pc" ];
          tui.cpuQueues = [{ mpiThreads = 4; openmpThreads = 4; memoryGB = 56; }];
        };
        ollama = {};
        podman = {};
        ananicy = {};
        keyd = {};
        kvm.aarch64 = true;
        peerBanHelper = {};
        mariadb.mountFrom = "nodatacow";
        lumericalLicenseManager.macAddress = "10:5f:ad:10:3e:ca";
      };
      bugs = [ "xmunet" "amdpstate" "iwlwifi" ];
      # packages = { mathematica = {}; vasp = {}; lumerical = {}; };
      user.users = [ "chn" "xly" ];
    };
    # 允许kvm读取物理硬盘
    users.users.qemu-libvirtd.extraGroups = [ "disk" ];
    services.colord.enable = true;
  };
}
