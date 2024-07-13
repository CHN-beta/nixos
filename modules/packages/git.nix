inputs:
{
  config = inputs.lib.mkIf (builtins.elem "server" inputs.config.nixos.packages._packageSets)
  {
    programs.git =
    {
      enable = true;
      package = inputs.pkgs.gitFull;
      lfs.enable = true;
      config =
      {
        init.defaultBranch = "main";
        core.quotepath = false;
      };
    };
    nixos.packages._packages = [ inputs.pkgs.localPackages.git-lfs-transfer ]; # make pure ssh lfs work
  };
}
