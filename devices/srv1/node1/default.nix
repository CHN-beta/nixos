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
          eno2 = { ip = "192.168.178.2"; mask = 24; gateway = "192.168.178.1"; dns = "192.168.178.1"; };
        };
        cluster.nodeType = "worker";
        initrd.sshd.enable = true;
        nix.remote.slave.enable = true;
      };
      services.beesd.instances.root = { device = "/"; hashTableSizeMB = 256; threads = 4; };
      packages.packages._prebuildPackages =
        [ inputs.topInputs.self.nixosConfigurations.srv1-node0.config.system.build.toplevel ];
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
    boot.initrd.systemd.network.networks."10-eno2" = inputs.config.systemd.network.networks."10-eno2";
    boot.initrd.systemd.extraBin =
    {
      "ifconfig" = "${inputs.pkgs.nettools}/bin/ifconfig";
      "mount.nfs" = "${inputs.pkgs.nfs-utils}/bin/mount.nfs";
      "mount.nfs4" = "${inputs.pkgs.nfs-utils}/bin/mount.nfs4";
    };
    services.rpcbind.enable = true;
    # make slurm sub process to be able to communicate with the master
    networking.firewall.trustedInterfaces = [ "eno2" ];
  };
}
