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
          eno1 = { ip = "192.168.1.12"; mask = 24; gateway = "192.168.1.1"; dns = "192.168.1.1"; };
          eno2 = { ip = "192.168.178.3"; mask = 24; };
        };
        cluster.nodeType = "worker";
        fileSystems.mount =
        {
          nfs."192.168.178.1:/home" = "/home";
          btrfs."/dev/disk/by-partlabel/srv1-node2-nodatacow" =
            { "/nix/nodatacow" = "/nix/nodatacow"; "/nix/backups" = "/nix/backups"; };
        };
      };
      services =
      {
        xray.client.enable = true;
        beesd.instances.root = { device = "/"; hashTableSizeMB = 256; threads = 4; };
      };
      packages.packages._prebuildPackages =
        [ inputs.topInputs.self.nixosConfigurations.srv1-node0.config.system.build.toplevel ];
      virtualization.kvmHost = { enable = true; gui = true; };
    };
    specialisation.no-share-home.configuration =
    {
      nixos.system.fileSystems.mount.nfs = inputs.lib.mkForce null;
      system.nixos.tags = [ "no-share-home" ];
    };
    boot.initrd.systemd.network.networks."10-eno2" = inputs.config.systemd.network.networks."10-eno2";
    # make slurm sub process to be able to communicate with the master
    networking.firewall.trustedInterfaces = [ "eno2" ];
    # add a bridge for kvm
    networking =
    {
      bridges.br0.interfaces = [ "eno1" ];
      interfaces.br0.useDHCP = true;
    };
  };
}
