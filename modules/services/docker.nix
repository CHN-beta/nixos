inputs:
{
  options.nixos.services.docker = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) docker; in inputs.lib.mkMerge
  [
    (
      inputs.lib.mkIf (docker != null)
      {
        # system-wide docker is not needed
        # virtualisation.docker.enable = true;
        virtualisation.docker.rootless =
        {
          enable = true;
          setSocketVariable = true;
          daemon.settings =
          {
            features.buildkit = true;
            # dns 127.0.0.1 make docker not work
            dns = [ "1.1.1.1" ];
            # prevent create btrfs subvol
            storage-driver = "overlay2";
          };
        };
      }
    )
    # some docker settings should be set unconditionally, as some services depend on them
    {
      virtualisation.docker =
      {
        enableNvidia = inputs.lib.mkIf inputs.config.nixos.system.nixpkgs.cuda.enable true;
        # prevent create btrfs subvol
        storageDriver = "overlay2";
        daemon.settings.dns = [ "1.1.1.1" ];
      };
      nixos.services.firewall.trustedInterfaces = [ "docker0" ];
    }
  ];
}
