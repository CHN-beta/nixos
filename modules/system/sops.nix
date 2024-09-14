inputs:
{
  options.nixos.system.sops = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = true; };
    keyPathPrefix = mkOption { type = types.str; default = "/nix/persistent"; };
  };
  config = let inherit (inputs.config.nixos.system) sops; in inputs.lib.mkIf sops.enable
  {
    sops =
    {
      defaultSopsFile =
        let deviceDir =
          if (inputs.config.nixos.system.cluster == null) then
            "${inputs.topInputs.self}/devices/${inputs.config.nixos.system.networking.hostname}"
          else
            "${inputs.topInputs.self}/devices/${inputs.config.nixos.system.cluster.clusterName}"
              + "/${inputs.config.nixos.system.cluster.nodeName}";
        in inputs.lib.mkMerge
        [
          (inputs.lib.mkIf (builtins.pathExists "${deviceDir}/secrets.yaml") "${deviceDir}/secrets.yaml")
          (inputs.lib.mkIf (builtins.pathExists "${deviceDir}/secrets/default.yaml")
            "${deviceDir}/secrets/default.yaml")
        ];
      # sops start before impermanence, so we need to use the absolute path
      age.sshKeyPaths = [ "${sops.keyPathPrefix}/etc/ssh/ssh_host_ed25519_key" ];
      gnupg.sshKeyPaths = [ "${sops.keyPathPrefix}/etc/ssh/ssh_host_rsa_key" ];
    };
  };
}
