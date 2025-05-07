inputs:
{
  config =
  {
    nixos =
    {
      model.type = "server";
      system =
      {
        fileSystems =
        {
          mount =
          {
            vfat."/dev/disk/by-partlabel/srv3-boot" = "/boot";
            btrfs."/dev/mapper/root1" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
          };
          swap = [ "/dev/mapper/swap" ];
          rollingRootfs = {};
        };
        nixpkgs.march = "haswell";
        initrd.sshd = {};
        networking.static.eno1 =
        {
          ip = "23.135.236.216";
          mask = 24;
          gateway = "23.135.236.1";
          dns = "8.8.8.8";
        };
      };
      hardware.cpus = [ "intel" ];
      services =
      {
        # 大部分空间用于存储虚拟机（nodatacow），其它内容不多
        beesd."/".hashTableSizeMB = 32;
        sshd = {};
        nixvirt =
        {
          alikia = { memoryGB = 1; cpus = 1; address = 2; portForward.tcp = [{ host = 5689; guest = 22; }]; };
          pen =
          {
            memoryGB = 1;
            cpus = 1;
            address = 3;
            portForward.tcp = [ { host = 5690; guest = 22; } { host = 5691; guest = 80; }{ host = 5692; guest = 443; }];
          };
        };
      };
      user.users = [ "chn" "aleksana" "alikia" "pen" ];
    };
    # TODO: use a generic way
    boot.initrd.systemd.network.networks."10-eno1" = inputs.config.systemd.network.networks."10-eno1";
  };
}
