inputs:
{
  options.nixos.model = let inherit (inputs.lib) mkOption types; in
  {
    hostname = mkOption { type = types.nonEmptyStr; };
    type = mkOption { type = types.enum [ "minimal" "desktop" "server" ]; default = "minimal"; };
    # not implemented yet
    # private = mkOption { type = types.bool; };
    cluster = mkOption
    {
      type = types.nullOr (types.submodule { options =
      {
        clusterName = mkOption { type = types.nonEmptyStr; };
        nodeName = mkOption { type = types.nonEmptyStr; };
        nodeType = mkOption { type = types.enum [ "master" "worker" ]; default = "worker"; };
      };});
      default = null;
    };
  };
  config = let inherit (inputs.config.nixos) model; in inputs.lib.mkMerge
  [
    { networking.hostName = model.hostname; }
    (inputs.lib.mkIf (model.cluster != null)
      { nixos.model.hostname = "${model.cluster.clusterName}-${model.cluster.nodeName}"; })
    # TODO: remove it
    {
      systemd.services = inputs.lib.mkIf (model.cluster.nodeType or null == "worker") (builtins.listToAttrs
        (builtins.map
          (user: { name = "home-manager-${inputs.utils.escapeSystemdPath user}"; value.enable = false; })
          inputs.config.nixos.user.users));
    }
  ];
}
