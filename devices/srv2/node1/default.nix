inputs:
{
  config =
  {
    nixos =
    {
      system =
      {
        nixpkgs.march = "skylake";
        network =
        {
          static.eno2 = { ip = "192.168.178.2"; mask = 24; gateway = "192.168.178.1"; dns = "192.168.178.1"; };
          trust = [ "eno2" ];
        };
        fileSystems.swap = [ "/nix/swap/swap" ];
      };
      services =
      {
        beesd."/".hashTableSizeMB = 64;
        lumericalLicenseManager.macAddress = "04:42:1a:26:0c:07";
      };
    };
  };
}
