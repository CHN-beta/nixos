inputs:
{
  config =
  {
    nixos =
    {
      system =
      {
        fileSystems =
        {
          mount =
          {
            btrfs =
            {
              "/dev/disk/by-uuid/e36287f7-7321-45fa-ba1e-d126717a65f0"."/boot" = "/boot";
              "/dev/mapper/root" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; };
            };
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs = {};
        };
        grub.installDevice = "/dev/disk/by-path/pci-0000:00:05.0-scsi-0:0:0:0";
        nixpkgs.march = "znver2";
        initrd.sshd = {};
        networking = {};
      };
      services =
      {
        sshd = {};
        rsshub = {};
        misskey.instances =
          { misskey.hostname = "xn--s8w913fdga.chn.moe"; misskey-old = { port = 9727; redis.port = 3546; }; };
        synapse.instances =
        {
          synapse.matrixHostname = "synapse.chn.moe";
          matrix = { port = 8009; redisPort = 6380; };
        };
        vaultwarden.enable = true;
        beesd."/".hashTableSizeMB = 128;
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
        xray.server.serverName = "xserver.vps7.chn.moe";
        docker = {};
        peertube = {};
        nginx.applications.webdav.instances."webdav.chn.moe" = {};
        open-webui.ollamaHost = "192.168.83.3";
      };
    };
  };
}
