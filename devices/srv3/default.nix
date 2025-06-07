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
        network =
        {
          bridge.nixvirt.interfaces = [ "eno1" ];
          static.nixvirt =
          {
            ip = "23.135.236.216";
            mask = 24;
            gateway = "23.135.236.1";
            dns = "8.8.8.8";
          };
        };
      };
      hardware.cpus = [ "intel" ];
      services =
      {
        beesd."/" = { hashTableSizeMB = 128; threads = 4;};
        sshd = {};
        nixvirt.instance =
        {
          alikia =
          {
            memory.sizeMB = 1024;
            cpu.count = 1;
            network = { address = 2; portForward.tcp = [{ host = 5689; guest = 22; }]; };
          };
          pen =
          {
            memory.sizeMB = 512;
            cpu.count = 1;
            network =
            {
              address = 3;
              portForward =
              {
                tcp =
                [
                  { host = 5690; guest = 22; }
                  { host = 5691; guest = 80; }
                  { host = 5692; guest = 443; }
                  { host = 22000; guest = 22000; }
                ];
                udp = [{ host = 22000; guest = 22000; }];
                web = [ "natsume.nohost.me" ];
              };
            };
          };
          test =
          {
            owner = "chn";
            memory.sizeMB = 512;
            cpu.count = 1;
            network =
            {
              address = 4;
              vnc.openFirewall = false;
              portForward = { tcp = [{ host = 5693; guest = 22; }]; web = [ "example.chn.moe" ]; };
            };
          };
          reonokiy =
          {
            memory.sizeMB = 4 * 1024;
            cpu.count = 4;
            network = { address = 5; portForward.tcp = [{ host = 5694; guest = 22; }]; };
          };
        };
        rsshub = {};
        misskey.instances =
          { misskey.hostname = "xn--s8w913fdga.chn.moe"; misskey-old = { port = 9727; redis.port = 3546; }; };
        synapse.instances =
        {
          synapse.matrixHostname = "synapse.chn.moe";
          matrix = { port = 8009; redisPort = 6380; };
        };
        vaultwarden.enable = true;
        photoprism.enable = true;
        nextcloud = {};
        freshrss = {};
        send = {};
        huginn = {};
        httpapi.enable = true;
        gitea = { enable = true; ssh = {}; };
        grafana = {};
        fail2ban = {};
        xray.server = {};
        docker = {};
        peertube = {};
        nginx.applications.webdav.instances."webdav.chn.moe" = {};
        open-webui.ollamaHost = "192.168.83.3";
      };
      user.users = [ "chn" "aleksana" "alikia" "pen" "reonokiy" ];
    };
  };
}
