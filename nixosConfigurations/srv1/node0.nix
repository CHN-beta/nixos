{
  config = {
    nixos = {
      model.cluster.nodeType = "master";
      system = {
        nixpkgs.march = "cascadelake";
        network.settings = {
          static = {
            eno145.ipv4 = {
              ip = "192.168.1.10";
              mask = 24;
              gateway = "192.168.1.1";
            };
            eno146.ipv4 = {
              ip = "192.168.178.1";
              mask = 24;
            };
          };
          masquerade = [ "eno146" ];
          trust = [ "eno146" ];
        };
      };
      services = {
        sshd.motd = true;
        beesd."/" = {
          hashTableSizeMB = 128;
          threads = 4;
        };
        lumericalLicenseManager.macAddress = "34:48:ed:f8:59:9c";
      };
    };
  };
}
