inputs:
{
  options.nixos.services.docker = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) docker; in inputs.lib.mkIf (docker != null)
  {
    virtualisation.docker =
    {
      enable = true;
      # prevent create btrfs subvol
      storageDriver = "overlay2";
      daemon.settings.dns = [ "1.1.1.1" ];
      rootless =
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
    };
    hardware.nvidia-container-toolkit.enable = inputs.lib.mkIf (inputs.config.nixos.system.nixpkgs.cuda != null) true;
    networking.firewall.trustedInterfaces = [ "docker0" ];
  };
}
