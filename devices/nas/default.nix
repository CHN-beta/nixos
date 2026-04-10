{ topInputs, lib, ...}:
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
          luks.auto =
          {
            "/dev/disk/by-partlabel/nas-root1".mapper = "root1";
            "/dev/disk/by-partlabel/nas-root2".mapper = "root2";
            "/dev/disk/by-partlabel/nas-root3" = { mapper = "root3"; ssd = true; };
            "/dev/disk/by-partlabel/nas-root4" = { mapper = "root4"; ssd = true; };
            "/dev/disk/by-partlabel/nas-swap" = { mapper = "swap"; ssd = true; };
            "/dev/disk/by-partlabel/nas-ssd1" = { mapper = "ssd1"; ssd = true; };
            "/dev/disk/by-partlabel/nas-ssd2" = { mapper = "ssd2"; ssd = true; };
          };
        };
        initrd.sshd = {};
        nixpkgs.march = "alderlake";
        nix.marches = topInputs.self.nixosConfigurations.pc.config.nixos.system.nix.marches;
        network.settings.static =
        {
          enp3s0 = { ip = "192.168.1.2"; mask = 24; gateway = "192.168.1.1"; dns = "192.168.1.1"; };
          enp2s0 = { ip = "192.168.178.10"; mask = 24; gateway = "192.168.178.1"; dns = "192.168.1.1"; };
        };
        kernel.patches = [ "btrfs" ];
        binfmt = {};
      };
      hardware = { gpu.type = "intel"; ugreen = {}; };
      services =
      {
        sshd = {};
        xray.client =
        {
          xray.serverAddress = topInputs.self.config.dns."chn.moe".getAddress "vps9";
          coredns = { extraInterfaces = [ "enp3s0" ]; hosts."git.chn.moe" = "127.0.0.1"; };
        };
        beesd."/".hashTableSizeMB = 10 * 128;
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
        nfs = { exports."/nix/persistent" = [ "100.97.101.0/24" ]; crossmnt = false; };
        immich = {};
        readeck = {};
        minibox = {};
      };
    };
    systemd.tmpfiles.rules =
      [ "w /sys/class/powercap/intel-rapl/intel-rapl:0/constraint_0_power_limit_uw - - - - 10000000" ];
    specialisation.desktop.configuration.nixos =
    {
      model.type = lib.mkForce "desktop";
      system =
      {
        network.implementation = "systemd-networkd";
        nixpkgs.march = lib.mkForce null;
      };
    };
  };
}
