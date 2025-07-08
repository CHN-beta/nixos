inputs:
{
  config =
  {
    nixos =
    {
      model.cluster.nodeType = "master";
      system =
      {
        nixpkgs.march = "znver3";
        network =
        {
          static.enp58s0 = { ip = "192.168.178.2"; mask = 24; };
          trust = [ "enp58s0" ];
          wireless = [ "457的5G" ];
          masquerade = [ "enp58s0" ];
        };
      };
      services.beesd."/".hashTableSizeMB = 64;
    };
    services.hardware.bolt.enable = true;
  };
}
