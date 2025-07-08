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
          static.eno2 = { ip = "192.168.178.1"; mask = 24; gateway = "192.168.178.2"; dns = "192.168.178.2"; };
          trust = [ "eno2" ];
        };
        nix.remote.slave = {};
      };
      services =
      {
        ollama = {};
        beesd."/" = { hashTableSizeMB = 16; loadAverage = 8; };
      };
    };
  };
}
