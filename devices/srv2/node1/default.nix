inputs:
{
  config =
  {
    nixos =
    {
      hardware.cpu = "amd";
      system =
      {
        nixpkgs.march = "znver3";
        network =
        {
          static.enp58s0 =
            { ip = "192.168.178.2"; mask = 24; gateway = "192.168.178.1"; dns = "192.168.178.1"; };
          trust = [ "enp58s0" ];
        };
      };
      services.beesd."/".hashTableSizeMB = 64;
    };
    services.hardware.bolt.enable = true;
  };
}
