{ pkgs, lib, ... }:
{
  imports = lib.findModules ./.;
  config = {
    nixos = {
      model = {
        variant = "desktop";
        private = true;
      };
      system = {
        fileSystems = {
          mount = {
            vfat."/dev/disk/by-partlabel/pc-boot" = "/boot";
            btrfs = {
              "/dev/lvm/root1" = {
                "/nix/rootfs/current" = "/";
                "/nix" = "/nix";
              };
            };
            nfs."nas.ts.chn.moe:/nix/export" = {
              mountPoint = "/nix/remote/nas";
              mountBeforeSwitch = false;
            };
          };
          luks.devices = {
            "/dev/disk/by-partlabel/pc-root1" = {
              mapper = "root1";
              ssd = true;
            };
            "/dev/disk/by-partlabel/pc-tf2" = {
              mapper = "tf2";
              ssd = true;
            };
          };
          swap = [ "/dev/lvm/swap" ];
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
        kernel = {
          variant = "xanmod-latest";
          patches = [ "btrfs" ];
        };
      };
      hardware = {
        gpu = {
          type = [
            "amd"
            "nvidia"
          ];
          nvidia.persistence = false;
        };
        asus = {
          rearGlow.enable = true;
        };
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
        misskey.instances.misskey.hostname = "xn--qbtm095lrg0bfka60z.chn.moe";
        beesd."/" = {
          hashTableSizeMB = 2 * 128;
          threads = 4;
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
        podman = { };
        ananicy = { };
        kvm = { };
        mariadb.mountFrom = "nodatacow";
        lumericalLicenseManager.macAddress = "a8:e2:91:52:5f:7c";
        howdy = { };
        # for debug and development
        postgresql.instances = {
          minibox = { };
          ddml = { };
        };
        bge-m3 = {
          hostname = "bgem3-fast.chn.moe";
          gpu = true;
        };
      };
      packages = {
        mathematica = { };
        vasp = { };
        lumerical = { };
        omp.users = [
          "chn"
          "straycat"
        ];
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
    services.udev = {
      extraRules = ''
        # 禁止鼠标等在睡眠时唤醒
        ACTION=="add", ATTR{power/wakeup}="disabled"
        # CPU降压
        SUBSYSTEM=="power_supply", KERNEL=="BAT0", ACTION=="*", RUN+="${pkgs.ryzenadj}/bin/ryzenadj --set-coall=0x0fff40"
      '';
      extraHwdb = ''
        # 交换键盘按键
        evdev:input:b*v*p*e*
         KEYBOARD_KEY_70039=leftmeta
         KEYBOARD_KEY_700e3=capslock
      '';
    };
    boot.kernelParams = [
      # 禁用蓝牙自动休眠以防 MT7925 死机
      "btusb.enable_autosuspend=0"
      # 解决有时蓝牙不能使用的问题
      "mt7925e.disable_aspm=1"
      # 插拔电源和扩展坞不要唤醒电脑
      "acpi.ec_no_wakeup=1"
      # fix tf card bug
      "sdhci.debug_quirks2=0x4"
      # fix amdgpu hang
      "amdgpu.dcdebugmask=0x410"
    ];
    # 手写笔
    hardware.opentabletdriver.enable = true;
    # 从休眠/睡眠中恢复后，重载重力传感器
    powerManagement.resumeCommands = ''
      ${pkgs.kmod}/bin/modprobe -r hid_sensor_accel_3d hid_sensor_trigger hid_sensor_iio_common hid_sensor_custom
      ${pkgs.kmod}/bin/modprobe -r hid_sensor_hub
      sleep 1
      ${pkgs.kmod}/bin/modprobe -a hid_sensor_hub hid_sensor_accel_3d hid_sensor_trigger hid_sensor_iio_common hid_sensor_custom
    '';
  };
}
