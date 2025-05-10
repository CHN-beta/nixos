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
        beesd."/" = { hashTableSizeMB = 128; threads = 4;};
        sshd = {};
        nixvirt =
        {
          alikia = { memoryMB = 1024; cpus = 1; address = 2; portForward.tcp = [{ host = 5689; guest = 22; }]; };
          pen =
          {
            memoryMB = 512;
            cpus = 1;
            address = 3;
            portForward =
            {
              tcp =
              [
                { host = 5690; guest = 22; }
                { host = 5691; guest = 80; }
                { host = 5692; guest = 443; }
              ];
              web = [ "natsume.nohost.me" ];
            };
          };
          test = { memoryMB = 4 * 1024; cpus = 1; address = 4; owner = "chn"; vnc.openFirewall = false; };
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
        freshrss.enable = true;
        send = {};
        huginn = {};
        fz-new-order = {};
        httpapi.enable = true;
        gitea = { enable = true; ssh = {}; };
        grafana = {};
        fail2ban = {};
        xray.server.serverName = "xserver.srv3.chn.moe";
        docker = {};
        peertube = {};
        nginx.applications.webdav.instances."webdav.chn.moe" = {};
        open-webui.ollamaHost = "192.168.83.3";
      };
      user.users = [ "chn" "aleksana" "alikia" "pen" ];
    };
    # TODO: use a generic way
    boot.initrd.systemd.network.networks."10-eno1" = inputs.config.systemd.network.networks."10-eno1";
  };
}
