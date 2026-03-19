{ pkgs, ... }:
{
  config =
  {
    nixos =
    {
      model.arch = "aarch64";
      system =
      {
        fileSystems =
        {
          mount.btrfs."/dev/disk/by-partlabel/r2s-root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
          swap = [ "/nix/swap/swap" ];
        };
        # uboot 起始位置 0x8000 字节，这个地方还在分区表内部；除此以外还需要预留一些空间，预留32M足够。
        uboot.buildArgs =
        {
          defconfig = "nanopi-r2s-rk3328_defconfig";
          filesToInstall = [ "u-boot-rockchip.bin" ];
          env.BL31 = "${pkgs.armTrustedFirmwareRK3328}/bl31.elf";
        };
      };
      services =
      {
        sshd = {};
      };
    };
  };
}
