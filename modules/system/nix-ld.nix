inputs:
{
  config =
  {
    programs.nix-ld =
    {
      enable = true;
      libraries = [(inputs.pkgs.runCommand "steamrun-lib" {}
        "mkdir $out; ln -s ${inputs.pkgs.steam-run.fhsenv}/usr/lib64 $out/lib")];
    };
  };
}
