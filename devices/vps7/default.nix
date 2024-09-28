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
          luks.manual =
          {
            enable = true;
            devices."/dev/disk/by-uuid/db48c8de-bcf7-43ae-a977-60c4f390d5c4" = { mapper = "root"; ssd = true; };
            delayedMount = [ "/" ];
          };
          swap = [ "/nix/swap/swap" ];
          rollingRootfs = {};
        };
        grub.installDevice = "/dev/disk/by-path/pci-0000:00:05.0-scsi-0:0:0:0";
        nixpkgs.march = "znver2";
        nix.substituters = [ "https://nix-store.chn.moe?priority=100" ];
        initrd.sshd.enable = true;
        networking.networkd = {};
        kernel.variant = "xanmod-lts";
      };
      services =
      {
        snapper.enable = true;
        sshd = {};
        rsshub.enable = true;
        wallabag.enable = true;
        misskey.instances =
          { misskey.hostname = "xn--s8w913fdga.chn.moe"; misskey-old = { port = 9727; redis.port = 3546; }; };
        synapse.instances =
        {
          synapse.matrixHostname = "synapse.chn.moe";
          matrix = { port = 8009; redisPort = 6380; slidingSyncPort = 9001; };
        };
        vaultwarden.enable = true;
        beesd.instances.root = { device = "/"; hashTableSizeMB = 512; };
        photoprism.enable = true;
        nextcloud = {};
        freshrss.enable = true;
        send.enable = true;
        huginn.enable = true;
        fz-new-order = {};
        nginx.applications = { kkmeeting.enable = true; webdav.instances."webdav.chn.moe" = {}; blog = {}; };
        httpapi.enable = true;
        gitea = { enable = true; ssh = {}; };
        grafana.enable = true;
        fail2ban = {};
        wireguard =
        {
          enable = true;
          peers = [ "vps6" ];
          publicKey = "n056ppNxC9oECcW7wEbALnw8GeW7nrMImtexKWYVUBk=";
          wireguardIp = "192.168.83.2";
          listenIp = "144.126.144.62";
        };
        vikunja.enable = true;
        chatgpt = {};
        xray.server = { serverName = "xserver.vps7.chn.moe"; userNumber = 4; };
        writefreely = {};
        docker = {};
        peertube = {};
      };
    };
    specialisation.generic.configuration =
    {
      nixos.system.nixpkgs.march = inputs.lib.mkForce null;
      system.nixos.tags = [ "generic" ];
    };
  };
}
