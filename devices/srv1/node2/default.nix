inputs:
{
  config =
  {
    nixos =
    {
      system =
      {
        nixpkgs.march = "broadwell";
        network.settings =
        {
          static =
          {
            br0 = { ip = "192.168.1.12"; mask = 24; gateway = "192.168.1.1"; };
            eno2 = { ip = "192.168.178.3"; mask = 24; };
          };
          trust = [ "eno2" ];
          bridge.br0.interfaces = [ "eno1" ];
        };
        fileSystems.mount.btrfs."/dev/disk/by-partlabel/srv1-node2-nodatacow" =
          { "/nix/nodatacow" = "/nix/nodatacow"; "/nix/backups" = "/nix/backups"; };
      };
      services =
      {
        beesd."/".threads = 4;
        kvm.nodatacow = true;
      };
    };
  };
}
