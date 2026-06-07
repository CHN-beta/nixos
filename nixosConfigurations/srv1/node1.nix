{
  config = {
    nixos = {
      system = {
        nixpkgs.march = "broadwell";
        network.settings = {
          static.eno2 = {
            ip = "192.168.178.2";
            mask = 24;
            gateway = "192.168.178.1";
          };
          trust = [ "eno2" ];
        };
      };
      services = {
        beesd."/".threads = 4;
        lumericalLicenseManager.macAddress = "80:18:44:e2:6b:c1";
      };
    };
  };
}
