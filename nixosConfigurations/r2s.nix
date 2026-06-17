{ pkgs, ... }:
{
  config = {
    nixos = {
      model.arch = "aarch64";
      system = {
        # 带贴纸的接口是 enu1，不带贴纸的接口是 end0
        fileSystems = {
          mount = {
            vfat."/dev/disk/by-uuid/BCB5-1029" = "/boot";
            btrfs."/dev/disk/by-uuid/fc6cd887-93cb-46cc-994e-4259766fa9ed" = {
              "/nix" = "/nix";
              "/nix/rootfs/current" = "/";
            };
          };
          swap = [ "/nix/swap/swap" ];
        };
        # uboot 起始位置 0x8000 字节，这个地方还在分区表内部；除此以外还需要预留一些空间，预留32M足够。
        uboot.buildArgs = {
          defconfig = "nanopi-r2s-rk3328_defconfig";
          filesToInstall = [
            "u-boot-rockchip.bin"
            "idbloader.img"
            "u-boot.itb"
          ];
          env.BL31 = "${pkgs.armTrustedFirmwareRK3328}/bl31.elf";
        };
      };
      services = {
        sshd = { };
        # pppoe.interface = "enu1";
      };
    };
  };
}
