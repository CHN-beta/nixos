{
  config = {
    nixos = {
      system = {
        nixpkgs.march = "icelake-server";
        network.settings = {
          static.eno8303 = {
            ip = "192.168.178.3";
            mask = 24;
            gateway = "192.168.178.1";
          };
          trust = [ "eno8303" ];
        };
        fileSystems.swap = [ "/nix/swap/swap" ];
      };
      services = {
        beesd."/" = { };
        lumericalLicenseManager.macAddress = "b4:e9:b8:fc:9a:f9";
        jupyterhub = { };
      };
      hardware.gpu.nvidia = {
        datacenter = true;
        disableFabricmanager = true;
      };
    };
  };
}
