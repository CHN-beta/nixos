inputs:
{
  options.nixos.services.podman = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) podman; in inputs.lib.mkIf (podman != null)
  {
    virtualisation =
    {
      containers.enable = true;
      podman =
      {
        enable = true;
        # Create a `docker` alias for podman, to use it as a drop-in replacement
        dockerCompat = true;
        # Required for containers under podman-compose to be able to talk to each other.
        defaultNetwork.settings.dns_enabled = true;
      };
    };
    hardware.nvidia-container-toolkit.enable = inputs.lib.mkIf (inputs.config.nixos.system.nixpkgs.cuda != null) true;
  };
}
