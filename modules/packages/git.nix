{ lib, config, ... }:
{
  options.nixos.packages.git = lib.mkOption
    { type = lib.types.nullOr (lib.types.submodule {}); default = {}; };
  config = let inherit (config.nixos.packages) git; in lib.mkIf (git != null)
  {
    programs.git =
    {
      enable = true;
      # do not use gitFull, otherwise it will use its own ssh
      # package = inputs.pkgs.gitFull;
      lfs = { enable = true; enablePureSSHTransfer = true; };
      config =
      {
        init.defaultBranch = "main";
        core.quotepath = false;
        lfs.ssh.automultiplex = false; # 避免 lfs 一直要求触摸 yubikey
        receive.denyCurrentBranch = "warn"; # 允许 push 到非 bare 的仓库
        merge.ours.driver = true; # 允许 .gitattributes 中设置的 merge=ours 生效
        advice.addIgnoredFile = false; # 关闭 add 忽略文件时的提示
      };
    };
  };
}
