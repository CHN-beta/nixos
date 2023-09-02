inputs:
{
  options.nixos.system.sops = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    keyPathPrefix = mkOption { type = types.str; default = ""; };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos.system) sops;
    in mkIf sops.enable
    {
      sops =
      {
        defaultSopsFile = ../../secrets/${inputs.config.networking.hostName}.yaml;
        # sops start before impermanence, so we need to use the absolute path
        age.sshKeyPaths = [ "${sops.keyPathPrefix}/etc/ssh/ssh_host_ed25519_key" ];
        gnupg.sshKeyPaths = [ "${sops.keyPathPrefix}/etc/ssh/ssh_host_rsa_key" ];
      };
    };
}
