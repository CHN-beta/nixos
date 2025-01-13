inputs:
{
  config = let inherit (inputs.config.nixos) user; in inputs.lib.mkIf (builtins.elem "hjp" user.users)
  {
    home-manager.users.hjp.config.programs.zsh.initExtra =
    ''
      export PATH=$PATH:/home/hjp/software/intel/oneapi/compiler/latest/bin
      export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/hjp/software/intel/oneapi/compiler/latest/lib
    '';
  };
}
