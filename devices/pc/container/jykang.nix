inputs:
{
  config =
  {
    nixos =
    {
      model.type = "minimal";
      system.nixpkgs.march = "znver4";
      hardware.cpus = [ "amd" ];
    };
  };
}
