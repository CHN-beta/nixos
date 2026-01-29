{ config, lib, ... }:
{
  config = let inherit (config.nixos) user; in lib.mkIf (builtins.elem "zgq" user.users)
  {
    users.users = lib.mkIf (config.nixos.model.cluster.clusterName or null == "srv1")
    {
      zgq.extraGroups = [ "wheel" ];
      root.openssh.authorizedKeys.keys = [(builtins.readFile ./keys/zgq)];
    };
  };
}
