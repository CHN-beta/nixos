inputs:
{
  config =
  {
    nixos =
    {
      system =
      {
        nixpkgs.march = "broadwell";
        networking.static.eno2 =
          { ip = "192.168.178.2"; mask = 24; gateway = "192.168.178.1"; dns = "192.168.178.1"; };
        initrd.network = {};
      };
      services.beesd."/".threads = 4;
    };
    # make slurm sub process to be able to communicate with the master
    networking.firewall.trustedInterfaces = [ "eno2" ];
  };
}
