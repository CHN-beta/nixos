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
        lfs.ssh.automultiplex = false; # 避免 lfs 一直要求触摸 yubikey
      };
    };
    nixos.packages._packages = [ inputs.pkgs.localPackages.git-lfs-transfer ]; # make pure ssh lfs work
  };
}
