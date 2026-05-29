{ self, ...}:
{
  config =
  {
    nixos =
    {
      model = { variant = "server"; private = true; };
      system =
      {
        fileSystems =
        {
          mount =
          {
            vfat."/dev/disk/by-partlabel/nas-boot" = "/boot";
            btrfs =
            {
              "/dev/lvm/root1" = { "/nix" = "/nix"; "/nix/rootfs/current" = "/"; "/" = "/nix/export"; };
              "/dev/lvm/ssd1"."/nix/ssd" = "/nix/ssd";
              "/dev/lvm/single1"."/nix" = "/nix/backup/nix";
            };
          };
          swap = [ "/dev/lvm/swap" ];
          luks =
          {
            "/dev/disk/by-partlabel/nas-root1".mapper = "root1";
            "/dev/disk/by-partlabel/nas-root2".mapper = "root2";
            "/dev/disk/by-partlabel/nas-root3" = { mapper = "root3"; ssd = true; };
            "/dev/disk/by-partlabel/nas-root4" = { mapper = "root4"; ssd = true; };
          };
          backup =
          {
            persistent = { device = "/dev/lvm/root1"; subvol = "/nix/persistent"; };
            ssd = { device = "/dev/lvm/ssd1"; subvol = "/nix/ssd"; };
          };
        };
        initrd.sshd = {};
        nixpkgs.march = "alderlake";
        # somehow needed by mounted-ssh-ng
        nix.marches = self.nixosConfigurations.pc.config.nixos.system.nix.marches;
        network.settings.static =
        {
          enp3s0 = { ip = "192.168.1.2"; mask = 24; gateway = "192.168.1.1"; dns = "192.168.1.1"; };
          enp2s0 = { ip = "192.168.178.10"; mask = 24; gateway = "192.168.178.1"; dns = "192.168.1.1"; };
        };
        kernel.patches = [ "btrfs" ];
        binfmt = {};
      };
      hardware = { gpu.type = [ "intel" ]; ugreen = {}; };
      services =
      {
        sshd = {};
        xray.client.coredns = { extraInterfaces = [ "enp3s0" ]; hosts."git.chn.moe" = "127.0.0.1"; };
        beesd =
        {
          "/".hashTableSizeMB = 10 * 128;
          "/nix/backup/nix".hashTableSizeMB = 3 * 128;
        };
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
        nfs = { exports."/nix/export" = [ "100.97.101.0/24" ]; crossmnt = false; };
        immich = {};
        readeck = {};
        minibox = {};
        harmonia = { hostname = "backup-store.chn.moe"; store = "/nix/backup";};
        snapper = { persistent = "/nix/persistent"; ssd = "/nix/ssd"; };
        github-runners = {};
      };
    };
    systemd.tmpfiles.rules =
      [ "w /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw - - - - 10000000" ];
  };
}
