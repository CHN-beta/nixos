{ config, lib, ... }:
{
  config = lib.mkIf (builtins.elem "hjp" config.nixos.user.users) {
    home-manager.users.hjp.config.programs.zsh.initContent = ''
      export PATH=$PATH:/home/hjp/software/intel/oneapi/compiler/latest/bin:/home/hjp/software/atomkit.0.9.0/bin
      export LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/home/hjp/software/intel/oneapi/compiler/latest/lib
    '';
    users.users.hjp.extraGroups = lib.mkIf (config.nixos.model.cluster.clusterName or null == "srv2") [
      "wheel"
    ];
  };
}
