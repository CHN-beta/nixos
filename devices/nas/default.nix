inputs:
{
  config =
  {
    nixos =
    {
      model.private = true;
      system =
      {
        fileSystems =
        {
          mount =
          {
            vfat."/dev/disk/by-partlabel/nas-boot" = "/boot";
            btrfs =
            {
              "/dev/mapper/root1" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
              "/dev/mapper/ssd1"."/nix/ssd" = "/nix/ssd";
            };
          };
          swap = [ "/dev/mapper/swap" ];
          # TODO: snapshot should take place just before switching root
          rollingRootfs.waitDevices =
            [ "/dev/mapper/root2" "/dev/mapper/root3" "/dev/mapper/root4" "/dev/mapper/ssd1" "/dev/mapper/ssd2" ];
        };
        initrd.sshd = {};
        nixpkgs.march = "alderlake";
        nix.marches = inputs.topInputs.self.nixosConfigurations.pc.config.nixos.system.nix.marches;
        network.settings.static.enp3s0 =
          { ip = "192.168.1.2"; mask = 24; gateway = "192.168.1.1"; dns = "192.168.1.1"; }; 
        kernel.patches = [ "btrfs" ];
      };
      hardware.gpu.type = "intel";
      services =
      {
        sshd = {};
        xray.client =
        {
          xray.serverName = "xserver2.vps9.chn.moe";
          dnsmasq = { extraInterfaces = [ "enp3s0" ]; hosts."git.chn.moe" = "127.0.0.1"; };
        };
        beesd."/".hashTableSizeMB = 10 * 128;
        nix-serve.hostname = "nix-store.nas.chn.moe";
        postgresql.mountFrom = "ssd";
        mariadb.mountFrom = "ssd";
        rsshub = {};
        misskey.instances =
          { misskey.hostname = "xn--s8w913fdga.chn.moe"; misskey-old = { port = 9727; redis.port = 3546; }; };
        synapse.instances =
        {
          synapse.matrixHostname = "synapse.chn.moe";
          matrix = { port = 8009; redisPort = 6380; };
        };
        vaultwarden = {};
        photoprism = {};
        nextcloud = {};
        freshrss = {};
        send = {};
        huginn = {};
        httpapi = {};
        gitea = {};
        grafana = {};
        podman = {};
        peertube = {};
        nginx.applications.webdav.instances."webdav.chn.moe" = {};
        nfs."/" = [ "100.97.101.0/24" ];
      };
    };
    systemd.tmpfiles.rules =
      [ "w /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw - - - - 10000000" ];
  };
}
