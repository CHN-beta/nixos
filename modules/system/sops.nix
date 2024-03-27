inputs:
{
  options.nixos.system.sops = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = true; };
    keyPathPrefix = mkOption { type = types.str; default = "/nix/persistent"; };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos.system) sops;
    in mkIf sops.enable
    {
      sops =
      {
        defaultSopsFile =
          let deviceDir = "${inputs.topInputs.self}/devices/${inputs.config.nixos.system.networking.hostname}";
          in
            if builtins.pathExists "${deviceDir}/secrets.yaml" then "${deviceDir}/secrets.yaml"
            else "${deviceDir}/secrets/default.yaml";
        # sops start before impermanence, so we need to use the absolute path
        age.sshKeyPaths = [ "${sops.keyPathPrefix}/etc/ssh/ssh_host_ed25519_key" ];
        gnupg.sshKeyPaths = [ "${sops.keyPathPrefix}/etc/ssh/ssh_host_rsa_key" ];
      };
    };
}
