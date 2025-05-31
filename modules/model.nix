inputs:
{
  options.nixos.model = let inherit (inputs.lib) mkOption types; in
  {
    hostname = mkOption { type = types.nonEmptyStr; };
    type = mkOption { type = types.enum [ "minimal" "desktop" "server" ]; default = "minimal"; };
    private = mkOption { type = types.bool; default = false; };
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
  ];
}
