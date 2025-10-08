inputs:
{
  config =
  {
    nixos =
    {
      system =
      {
        nixpkgs.march = "icelake-server";
        network =
        {
          static.eno2 = { ip = "192.168.178.3"; mask = 24; };
          trust = [ "eno2" ];
        };
        fileSystems =
        {
          swap = [ "/nix/swap/swap" ];
          mount.btrfs."/dev/disk/by-partlabel/srv2-node2-root1" =
          {
            "/nix/remote/jykang.xmuhpc" = "/data/gpfs01/jykang/.nix";
            "/nix/remote/xmuhk" = "/public/home/xmuhk/.nix";
          };
        };
      };
      services =
      {
        beesd."/" = { hashTableSizeMB = 128; loadAverage = 8; };
        lumericalLicenseManager.macAddress = "70:20:84:09:a3:52";
      };
    };
  };
}
