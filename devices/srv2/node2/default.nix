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
        {
          # TODO: set correct interface name
          static.eno2 = { ip = "192.168.178.3"; mask = 24; gateway = "192.168.178.1"; dns = "192.168.178.1"; };
          trust = [ "eno2" ];
        };
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
        # TODO: set correct MAC address
        lumericalLicenseManager.macAddress = "70:20:84:09:a3:52";
      };
    };
  };
}
