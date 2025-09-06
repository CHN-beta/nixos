inputs:
{
  config =
  {
    nixos =
    {
      model = { type = "server"; private = true; };
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
        network = {};
        kernel.patches = [ "btrfs" ];
      };
      hardware.gpu.type = "intel";
      services =
      {
        sshd = {};
        xray =
        {
          client.dnsmasq = { extraInterfaces = [ "enp3s0" ]; hosts."git.nas.chn.moe" = "127.0.0.1"; };
          xmuServer = {};
          server.serverName = "xservernas.chn.moe";
        };
        beesd."/" = { hashTableSizeMB = 10 * 128; threads = 4; };
        nfs."/" = [(inputs.topInputs.self.config.dns."chn.moe".getAddress "wg1.pc")];
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
        huginn = {}; # somehow it does not work
        httpapi = {};
        gitea = {};
        grafana = {};
        podman = {};
        peertube = {};
        nginx.applications.webdav.instances."webdav.chn.moe" = {};
        # open-webui.ollamaHost = "192.168.83.3";
      };
    };
    systemd.tmpfiles.rules =
      [ "w /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw - - - - 10000000" ];
  };
}
