inputs:
{
  options.nixos.packages.git = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = {}; };
  config = let inherit (inputs.config.nixos.packages) git; in inputs.lib.mkIf (git != null)
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
        receive.denyCurrentBranch = "warn"; # 允许 push 到非 bare 的仓库
      };
    };
    nixos.packages.packages._packages = [ inputs.pkgs.localPackages.git-lfs-transfer ]; # make pure ssh lfs work
  };
}
