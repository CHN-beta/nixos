inputs:
{
  options.nixos.system.sops = let inherit (inputs.lib) mkOption types; in
  {
    crossSopsDir = mkOption
    {
      type = types.nonEmptyStr;
      default = "${inputs.topInputs.self}/devices/cross/secrets";
      readOnly = true;
    };
    clusterSopsDir = mkOption
    {
      type = types.nullOr types.nonEmptyStr;
      default = if (inputs.config.nixos.model.cluster == null) then null
        else "${inputs.topInputs.self}/devices/${inputs.config.nixos.model.cluster.clusterName}/secrets";
      readOnly = true;
    };
  };
  config =
  {
    sops =
    {
      defaultSopsFile =
        let deviceDir =
          if (inputs.config.nixos.model.cluster == null) then
            "${inputs.topInputs.self}/devices/${inputs.config.nixos.model.hostname}"
          else
            "${inputs.topInputs.self}/devices/${inputs.config.nixos.model.cluster.clusterName}"
              + "/${inputs.config.nixos.model.cluster.nodeName}";
        in inputs.lib.mkMerge
        [
          (inputs.lib.mkIf (builtins.pathExists "${deviceDir}/secrets.yaml") "${deviceDir}/secrets.yaml")
          (inputs.lib.mkIf (builtins.pathExists "${deviceDir}/secrets/default.yaml")
            "${deviceDir}/secrets/default.yaml")
        ];
      # sops start before impermanence, so we need to use the absolute path
      age.sshKeyPaths = [ "/nix/persistent/etc/ssh/ssh_host_ed25519_key" ];
    };
  };
}
