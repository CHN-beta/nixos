inputs:
{
  config =
  {
    nixos =
    {
      system =
      {
        nixpkgs.march = "icelake-server";
        network.settings =
          { static.eno8303 = { ip = "192.168.178.3"; mask = 24; gateway = "192.168.178.1"; }; trust = [ "eno8303" ]; };
        fileSystems =
        {
          swap = [ "/nix/swap/swap" ];
          mount.btrfs."/dev/disk/by-partlabel/srv2-node2-root1" =
          {
            "/nix/remote/jykang.xmuhpc" = "/data/gpfs01/jykang/.nix";
            "/nix/remote/xmuhk" = "/public/home/xmuhk/.nix";
            "/nix/remote/wlin" = "/data/gpfs01/wlin/.nix";
          };
        };
      };
      services =
      {
        beesd."/" = {};
        lumericalLicenseManager.macAddress = "b4:e9:b8:fc:9a:f9";
      };
    };
  };
}
