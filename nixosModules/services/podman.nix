{
  lib,
  config,
  pkgs,
  ...
}:
{
  options.nixos.services.podman = lib.mkOption {
    type = lib.types.nullOr (lib.types.submodule { });
    default = null;
  };
  config =
    let
      inherit (config.nixos.services) podman;
    in
    lib.mkIf (podman != null) {
      virtualisation = {
        containers = {
          enable = true;
          containersConf.settings.network.firewall_driver = "nftables";
        };
        podman = {
          enable = true;
          # Create a `docker` alias for podman, to use it as a drop-in replacement
          dockerCompat = true;
          # Required for containers under podman-compose to be able to talk to each other.
          defaultNetwork.settings.dns_enabled = true;
          extraPackages = [ pkgs.nftables ];
        };
      };
      hardware.nvidia-container-toolkit = {
        enable = lib.mkIf (config.nixos.system.nixpkgs.cuda != null) true;
        # suppress warning, triggered when dc driver is used but datacenter is false (libfabric is disabled),
        suppressNvidiaDriverAssertion = true;
      };
      networking.firewall.trustedInterfaces = [ "podman0" ];
    };
}
