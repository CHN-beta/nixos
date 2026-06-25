{ pkgs, lib, ... }:
{
  config = {
    nixos = {
      model = {
        variant = "desktop";
        private = true;
      };
      system = {
        fileSystems = {
          # windows partitions:
          #   /dev/nvme0n1p3, esp
          #   /dev/nvme0n1p4, ntfs
          # linux partition:
          #   esp: /dev/nvme0n1p1 or /dev/disk/by-partlabel/pc-boot
          #   most stuff: mounted from:
          #     /dev/mapper/root1 /dev/tf/pc-root2, btrfs
          #   nix build cache (/nix/remote/nix/store and hpc stuff): mounted from:
          #     /dev/bcache0 /dev/tf/nbd-metadata, btrfs
          #   swap: /dev/tf/pc-swap
          #   lvm:
          #     - /dev/mapper/tf2 -> /dev/tf/swap /dev/tf/pc-root2 /dev/tf/nbd-metadata /dev/tf/nbd-cache
          #   luks:
          #     - /dev/disk/by-partlabel/pc-root1 or /dev/nvme0n1p2 -> /dev/mapper/root1
          #     - /dev/disk/by-partlabel/pc-tf2 or /dev/nvme0n1p5 -> /dev/mapper/tf2
          #   bcache: /dev/tf/nbd-cache /dev/nbd1 -> /dev/bcache0
          mount = {
            vfat."/dev/disk/by-partlabel/pc-boot" = "/boot";
            btrfs = {
              "/dev/mapper/root1" = {
                "/nix/rootfs/current" = "/";
                "/nix" = "/nix";
              };
              "/dev/tf/tf" = {
                "/nix" = "/nix/tf/nix";
                "/nix/remote/xmuhk" = "/public/home/xmuhk";
                "/nix/remote/jykang" = "/data/gpfs01/jykang";
                "/nix/remote/wlin" = "/data/gpfs01/wlin";
                "/nix/remote/hwang" = "/data/gpfs01/hwang";
              };
            };
            nfs."nas.ts.chn.moe:/nix/export" = {
              mountPoint = "/nix/remote/nas";
              mountBeforeSwitch = false;
            };
          };
          luks = {
            "/dev/disk/by-partlabel/pc-root1" = {
              mapper = "root1";
              ssd = true;
            };
            "/dev/disk/by-partlabel/pc-tf1".mapper = "tf1";
            "/dev/disk/by-partlabel/pc-tf2" = {
              mapper = "tf2";
              ssd = true;
            };
          };
          swap = [ "/dev/tf/pc-swap" ];
        };
        grub.windowsEntries."08D3-10DE" = "Windows";
        nix.marches = [
          "znver2"
          "znver3"
          "znver4"
          "znver5"
          # FXSR HLE LZCNT PREFETCHW RDRND SAHF XSAVE
          "broadwell"
          # FXSR HLE LZCNT PREFETCHW RDRND SAHF SGX XSAVE
          "skylake"
          "cascadelake"
          # AVX-VNNI CLDEMOTE GFNI-SSE HRESET KL LZCNT PCONFIG PREFETCHW PTWRITE RDRND
          # SERIALIZE SGX WAITPKG WIDEKL XSAVE XSAVEOPT
          "alderlake"
          # SAHF FXSR XSAVE RDRND LZCNT HLE PREFETCHW SGX PCONFIG
          "icelake-server"
        ];
        nixpkgs = {
          march = "znver5";
          rocm.targets = [ "gfx1151" ];
        };
        sysctl.laptop-mode = 5;
        kernel.patches = [
          "btrfs"
        ];
      };
      hardware = {
        gpu = {
          type = [
            "amd"
            "nvidia"
          ];
          nvidia.persistence = false;
        };
        asus = { };
      };
      services = {
        samba = {
          hostsAllowed = "192.168. 127.";
          shares = {
            media.path = "/run/media/chn";
            home.path = "/home/chn";
            mnt.path = "/mnt";
            share.path = "/home/chn/share";
          };
        };
        sshd = { };
        xray.client.coredns = {
          hosts = builtins.listToAttrs (
            builtins.map
              (name: {
                inherit name;
                value = "144.34.225.59";
              })
              [
                "mirism.one"
                "beta.mirism.one"
                "ng01.mirism.one"
                "initrd.vps6.chn.moe"
              ]
          );
          extraInterfaces = [ "wlp194s0" ];
        };
        harmonia.store = "/nix/tf";
        misskey.instances.misskey.hostname = "xn--qbtm095lrg0bfka60z.chn.moe";
        beesd = {
          "/" = {
            hashTableSizeMB = 2 * 128;
            loadAverage = 4;
          };
          "/nix/tf/nix" = {
            hashTableSizeMB = 128;
            loadAverage = 4;
          };
        };
        slurm = {
          enable = true;
          master = "pc";
          node.pc = {
            name = "pc";
            address = "127.0.0.1";
            cpu = {
              sockets = 2;
              cores = 8;
              threads = 2;
            };
            memoryGB = 96;
          };
          partitions.localhost = [ "pc" ];
          tui.cpuQueues = [
            {
              mpiThreads = 4;
              openmpThreads = 4;
              memoryGB = 96;
            }
          ];
        };
        ollama = { };
        podman = { };
        ananicy = { };
        keyd = { };
        kvm = { };
        mariadb.mountFrom = "nodatacow";
        lumericalLicenseManager.macAddress = "a8:e2:91:52:5f:7c";
        open-webui.ollamaHost = "127.0.0.1";
        howdy = { };
        # for debug and development
        postgresql.instances.minibox = { };
        hermes = { };
      };
      packages = {
        mathematica = { };
        vasp = { };
        lumerical = { };
      };
      user.users = [
        "chn"
        "lilydjwg"
        "hjp"
        "straycat"
      ];
    };
    # 允许kvm读取物理硬盘
    users.users.qemu-libvirtd.extraGroups = [ "disk" ];
    services.colord.enable = true;
    services.udev.extraRules = ''
      # 禁止鼠标等在睡眠时唤醒
      ACTION=="add", ATTR{power/wakeup}="disabled"
      # CPU降压
      SUBSYSTEM=="power_supply", KERNEL=="BAT0", ACTION=="*", RUN+="${pkgs.ryzenadj}/bin/ryzenadj --set-coall=0x0fff40"
    '';
    boot.kernelParams = [
      # 解决有时蓝牙不能使用的问题
      "mt7925e.disable_aspm=1"
      # 插拔电源和扩展坞不要唤醒电脑
      "acpi.ec_no_wakeup=1"
      # fix tf card bug
      "sdhci.debug_quirks2=0x4"
    ];
    # 手写笔
    hardware.opentabletdriver.enable = true;
    # 从休眠/睡眠中恢复后，重载重力传感器
    powerManagement.resumeCommands = ''
      ${pkgs.kmod}/bin/modprobe -r hid_sensor_accel_3d hid_sensor_trigger hid_sensor_iio_common hid_sensor_custom
      ${pkgs.kmod}/bin/modprobe -r hid_sensor_hub
      sleep 1
      ${pkgs.kmod}/bin/modprobe hid_sensor_hub hid_sensor_accel_3d hid_sensor_trigger hid_sensor_iio_common hid_sensor_custom
    '';
    systemd = {
      # niri use only amd graphics
      user.services.niri = {
        overrideStrategy = "asDropin";
        enableDefaultPath = false;
        environment = {
          VK_ICD_FILENAMES = "/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json";
          __EGL_VENDOR_LIBRARY_FILENAMES = "/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json";
        };
      };
    };
  };
}
