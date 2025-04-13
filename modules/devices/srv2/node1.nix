inputs:
{
  config = inputs.lib.mkIf (inputs.config.nixos.model.hostname == "srv2-node1")
  {
    nixos =
    {
      hardware.cpus = [ "amd" ];
      system =
      {
        nixpkgs.march = "znver3";
        networking.static.enp58s0 =
          { ip = "192.168.178.2"; mask = 24; gateway = "192.168.178.1"; dns = "192.168.178.1"; };
      };
      services.beesd."/".hashTableSizeMB = 64;
    };
    services.hardware.bolt.enable = true;
    specialisation.no-share-home.configuration =
    {
      nixos.system.fileSystems.mount.nfs = inputs.lib.mkForce null;
      system.nixos.tags = [ "no-share-home" ];
    };
    boot.initrd.systemd.network.networks."10-enp58s0" = inputs.config.systemd.network.networks."10-enp58s0";
    # make slurm sub process to be able to communicate with the master
    networking.firewall.trustedInterfaces = [ "enp58s0" ];
  };
}
