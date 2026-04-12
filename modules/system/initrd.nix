{ lib, config, ... }:
{
  options.nixos.system.initrd =
  {
    sshd = lib.mkOption { type = lib.types.nullOr (lib.types.submodule {}); default = null; };
    network = lib.mkOption
    {
      type = lib.types.nullOr (lib.types.submodule { options =
      {
        # null: enable all interfaces configured in systemd.network
        interfaces = lib.mkOption { type = lib.types.nullOr (lib.types.listOf lib.types.nonEmptyStr); default = null; };
      };});
      default = null;
    };
  };
  config = let inherit (config.nixos.system) initrd; in lib.mkMerge
  [
    {
      boot =
      {
        initrd.systemd.enable = true;
        kernelParams = [ "boot.shell_on_fail" "systemd.setenv=SYSTEMD_SULOGIN_FORCE=1" ];
      };
    }
    (
      lib.mkIf (initrd.sshd != null)
      {
        boot.initrd.network.ssh =
          { enable = true; hostKeys = [ "/nix/persistent/etc/ssh/initrd_ssh_host_ed25519_key" ]; };
        nixos.system.initrd.network = {};
      }
    )
    (
      lib.mkIf (initrd.network != null)
      {
        assertions =
        [{
          assertion = config.nixos.system.network.implementation == "systemd-networkd";
          message = "initrd network requires systemd networkd.";
        }];
        boot =
        {
          initrd =
          {
            network.enable = true;
            # resolved does not work in initrd, causing network.target to fail
            services.resolved.enable = false;
            systemd.network =
              let inherit (config.nixos.system.network.settings) dhcp static bridge; in
              let
                networks = lib.unique
                (
                  dhcp ++ (builtins.attrNames static) ++ (builtins.attrNames bridge)
                  ++ (builtins.concatLists (builtins.map (network: network.interfaces) (builtins.attrValues bridge)))
                );
                netdevs = builtins.attrNames bridge;
              in
              {
                networks = builtins.listToAttrs (builtins.map
                  (network: { name = "10-${network}"; value = config.systemd.network.networks."10-${network}"; })
                  (builtins.filter
                    (network:
                      if initrd.network.interfaces == null then true
                      else builtins.elem network initrd.network.interfaces
                    )
                    networks));
                netdevs = builtins.listToAttrs (builtins.map
                  (netdev: { name = "10-${netdev}"; value = config.systemd.network.netdevs."10-${netdev}"; })
                  (builtins.filter
                    (netdev:
                      if initrd.network.interfaces == null then true
                      else builtins.elem netdev initrd.network.interfaces
                    )
                    netdevs));
              };
          };
          # do not use ip=xxx, as it will override systemd-networkd configurations
          # kernelParams = [ "ip=on" ];
        };
      }
    )
  ];
}
