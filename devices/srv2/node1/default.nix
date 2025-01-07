inputs:
{
  config =
  {
    nixos =
    {
      model.cluster.nodeType = "worker";
      hardware.cpus = [ "amd" ];
      system =
      {
        nixpkgs.march = "znver3";
        # TODO: network
        # networking.static.eno2 =
        #   { ip = "192.168.178.2"; mask = 24; gateway = "192.168.178.1"; dns = "192.168.178.1"; };
        fileSystems.mount.nfs."192.168.178.1:/home" = "/home";
      };
      services.beesd.instances.root = { device = "/"; hashTableSizeMB = 512; };
    };
    services.hardware.bolt.enable = true;
    specialisation.no-share-home.configuration =
    {
      nixos.system.fileSystems.mount.nfs = inputs.lib.mkForce null;
      system.nixos.tags = [ "no-share-home" ];
    };
    # TODO: network
    # boot.initrd.systemd.network.networks."10-eno2" = inputs.config.systemd.network.networks."10-eno2";
    # make slurm sub process to be able to communicate with the master
    # networking.firewall.trustedInterfaces = [ "eno2" ];
  };
}
