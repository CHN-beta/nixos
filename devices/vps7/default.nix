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
          decrypt.manual =
          {
            enable = true;
            devices."/dev/disk/by-uuid/db48c8de-bcf7-43ae-a977-60c4f390d5c4" = { mapper = "root"; ssd = true; };
            delayedMount = [ "/" ];
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs = { device = "/dev/mapper/root"; path = "/nix/rootfs"; };
        };
        grub.installDevice = "/dev/disk/by-path/pci-0000:00:05.0-scsi-0:0:0:0";
        nixpkgs.march = "broadwell";
        nix.substituters = [ "https://cache.nixos.org/" "https://nix-store.chn.moe" ];
        initrd.sshd.enable = true;
        impermanence.enable = true;
        networking.hostname = "vps7";
        gui.preferred = false;
      };
      packages.packageSet = "desktop";
      services =
      {
        snapper.enable = true;
        fontconfig.enable = true;
        sshd.enable = true;
        rsshub.enable = true;
        wallabag.enable = true;
        misskey.instances =
        {
          misskey.hostname = "xn--s8w913fdga.chn.moe";
          misskey-old = { port = 9727; redis.port = 3546; meilisearch.enable = false; };
        };
        synapse.instances =
        {
          synapse.matrixHostname = "synapse.chn.moe";
          matrix = { port = 8009; redisPort = 6380; slidingSyncPort = 9001; };
        };
        xrdp = { enable = true; hostname = [ "vps7.chn.moe" ]; };
        vaultwarden.enable = true;
        beesd = { enable = true; instances.root = { device = "/"; hashTableSizeMB = 1024; }; };
        photoprism.enable = true;
        nextcloud.enable = true;
        freshrss.enable = true;
        send.enable = true;
        huginn.enable = true;
        fz-new-order.enable = true;
        nginx.applications = { kkmeeting.enable = true; webdav.instances."webdav.chn.moe" = {}; };
        httpapi.enable = true;
        mastodon.enable = true;
        gitea.enable = true;
        grafana.enable = true;
        fail2ban.enable = true;
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "n056ppNxC9oECcW7wEbALnw8GeW7nrMImtexKWYVUBk=";
          wireguardIp = "192.168.83.2";
          externalIp = "95.111.228.40";
        };
      };
    };
  };
}
