inputs:
{
  config = inputs.lib.mkIf (inputs.config.nixos.model.hostname == "srv1-node1")
  {
    nixos =
    {
      system =
      {
        nixpkgs.march = "broadwell";
        networking.static.eno2 =
          { ip = "192.168.178.2"; mask = 24; gateway = "192.168.178.1"; dns = "192.168.178.1"; };
      };
      services.beesd."/".threads = 4;
    };
    specialisation.no-share-home.configuration =
    {
      nixos.system.fileSystems.mount.nfs = inputs.lib.mkForce null;
      system.nixos.tags = [ "no-share-home" ];
    };
    boot.initrd.systemd.network.networks."10-eno2" = inputs.config.systemd.network.networks."10-eno2";
    # make slurm sub process to be able to communicate with the master
    networking.firewall.trustedInterfaces = [ "eno2" ];
  };
}
