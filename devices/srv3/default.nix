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
          test =
          {
            uuid = "6cb275dc-19e5-4c8d-b705-5faab72aa3ee";
            storage = "test";
            memoryGB = 8;
            cpus = 4;
            vncPort = 15900;
            mac = "e2:ad:f6:29:8c:11";
            address = 2;
          };
        };
      };
      user.users = [ "chn" "aleksana" ];
    };
    # TODO: use a generic way
    boot.initrd.systemd.network.networks."10-eno1" = inputs.config.systemd.network.networks."10-eno1";
  };
}
