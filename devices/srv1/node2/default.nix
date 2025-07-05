inputs:
{
  config =
  {
    nixos =
    {
      system =
      {
        nixpkgs.march = "broadwell";
        network =
        {
          static.eno2 = { ip = "192.168.178.3"; mask = 24; gateway = "192.168.178.1"; dns = "192.168.178.1"; };
          trust = [ "eno2" ];
        };
        fileSystems.mount.btrfs."/dev/disk/by-partlabel/srv1-node2-nodatacow" =
          { "/nix/nodatacow" = "/nix/nodatacow"; "/nix/backups" = "/nix/backups"; };
      };
      services.beesd."/".threads = 4;
    };
  };
}
