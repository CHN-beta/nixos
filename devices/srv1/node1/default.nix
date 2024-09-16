inputs:
{
  config =
  {
    nixos =
    {
      system =
      {
        nixpkgs.march = "broadwell";
        networking.networkd.static =
        {
          eno1 = { ip = "192.168.1.11"; mask = 24; gateway = "192.168.1.1"; };
          eno2 = { ip = "192.168.178.2"; mask = 24; gateway = "192.168.178.1"; };
        };
        cluster.nodeType = "worker";
      };
      services.beesd.instances.root = { device = "/"; hashTableSizeMB = 256; threads = 4; };
      packages =
      {
        vasp = null;
        packages._packages = [(inputs.pkgs.runCommand "master-system" {}
        ''
          mkdir -p $out/share
          ln -s ${inputs.topInputs.self.nixosConfigurations.srv1-node0.config.system.build.toplevel} \
            $out/share/master-system
        '')];
      };
    };
    specialisation =
    {
      no-share-home.configuration =
      {
        nixos =
        {
          services.slurm.enable = inputs.lib.mkForce false;
          system.cluster.nodeType = inputs.lib.mkForce "master";
        };
        system.nixos.tags = [ "no-share-home" ];
      };
    };
    fileSystems = inputs.lib.mkIf (inputs.config.nixos.system.cluster.nodeType == "worker")
    {
      "/home" =
      {
        device = "192.168.178.1:/home";
        fsType = "nfs";
        neededForBoot = true;
      };
    };
    boot.initrd.network.enable = true; 
    services.rpcbind.enable = true;
  };
}
