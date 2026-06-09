{
  config = {
    nixos = {
      model.cluster.nodeType = "master";
      system = {
        nixpkgs.march = "znver3";
        network.settings = {
          static = {
            enp58s0 = {
              ip = "192.168.178.1";
              mask = 24;
            };
            enp56s0 = {
              ip = "192.168.1.2";
              mask = 24;
              gateway = "192.168.1.1";
            };
          };
          trust = [ "enp58s0" ];
          masquerade = [ "enp58s0" ];
        };
        fileSystems = {
          swap = [ "/dev/disk/by-partlabel/srv2-node0-swap" ];
        };
        kernel.patches = [ "btrfs" ];
      };
      services = {
        beesd."/".hashTableSizeMB = 10 * 128;
        hpcstat = { };
        sshd = {
          groupBanner = true;
          motd = true;
        };
        lumericalLicenseManager.macAddress = "04:42:1a:26:0c:07";
        nginx.streamProxy.map."jupyterhub.chn.moe".upstream.address = "tinc0.srv2-node2.chn.moe";
      };
    };
  };
}
