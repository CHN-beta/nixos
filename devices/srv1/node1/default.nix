inputs:
{
  config =
  {
    nixos =
    {
      system =
      {
        nixpkgs.march = "broadwell";
        networking =
        {
          static.eno2 =
            { ip = "192.168.178.2"; mask = 24; gateway = "192.168.178.1"; dns = "192.168.178.1"; };
          trust = [ "eno2" ];
        };
      };
      services.beesd."/".threads = 4;
    };
  };
}
