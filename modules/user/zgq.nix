inputs:
{
  config = let inherit (inputs.config.nixos) user; in inputs.lib.mkIf (builtins.elem "zgq" user.users)
  {
    users.users = inputs.lib.mkIf (inputs.config.nixos.model.cluster.clusterName or null == "srv1")
    {
      zgq.extraGroups = [ "wheel" ];
      root.openssh.authorizedKeys.keys = [(builtins.readFile ./keys/zgq)];
    };
  };
}
