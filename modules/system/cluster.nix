inputs:
{
  options.nixos.system.cluster = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule { options =
    {
      clusterName = mkOption { type = types.nonEmptyStr; };
      nodeName = mkOption { type = types.nonEmptyStr; };
      nodeType = mkOption { type = types.enum [ "master" "worker" ]; default = "worker"; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.system) cluster; in inputs.lib.mkIf (cluster != null)
  {
    nixos.system.networking.hostname = "${cluster.clusterName}-${cluster.nodeName}";
    # 作为从机时，home-manager 需要被禁用
    systemd.services = inputs.lib.mkIf (cluster.nodeType == "worker") (builtins.listToAttrs (builtins.map
      (user: { "home-manager-${user}".enable = false; })
      inputs.config.nixos.users.users));
  };
}
