inputs:
{
  options.nixos.system.initrd = let inherit (inputs.lib) mkOption types; in
  {
    sshd = mkOption { type = types.nullOr (types.submodule {}); default = null; };
    network = mkOption
    {
      type = types.nullOr (types.submodule { options =
      {
        # null: enable all interfaces configured in systemd.network
        interfaces = mkOption { type = types.nullOr (types.listOf types.nonEmptyStr); default = null; };
      };});
      default = null;
    };
  };
  config = let inherit (inputs.config.nixos.system) initrd; in inputs.lib.mkMerge
  [
    {
      boot =
      {
        initrd.systemd.enable = true;
        kernelParams = [ "boot.shell_on_fail" "systemd.setenv=SYSTEMD_SULOGIN_FORCE=1" ];
      };
    }
    (
      inputs.lib.mkIf (initrd.sshd != null)
      {
        boot.initrd.network.ssh =
          { enable = true; hostKeys = [ "/nix/persistent/etc/ssh/initrd_ssh_host_ed25519_key" ]; };
        nixos.system.initrd.network = {};
      }
    )
    (
      inputs.lib.mkIf (initrd.network != null)
      {
        assertions =
        [{
          assertion = inputs.config.nixos.system.networking != null;
          message = "initrd networking requires systemd networkd.";
        }];
        boot =
        {
          initrd =
          {
            network.enable = true;
            # resolved does not work in initrd, causing network.target to fail
            services.resolved.enable = false;
            systemd.network =
              let inherit (inputs.config.nixos.system.networking) dhcp static bridge; in
              let
                networks = inputs.lib.unique
                (
                  dhcp ++ (builtins.attrNames static) ++ (builtins.attrNames bridge)
                  ++ (builtins.concatLists (builtins.map (network: network.interfaces) (builtins.attrValues bridge)))
                );
                netdevs = builtins.attrNames bridge;
              in
              {
                networks = builtins.listToAttrs (builtins.map
                  (network: { name = "10-${network}"; value = inputs.config.systemd.network.networks."10-${network}"; })
                  (builtins.filter
                    (network:
                      if initrd.network.interfaces == null then true
                      else builtins.elem network initrd.network.interfaces
                    )
                    networks));
                netdevs = builtins.listToAttrs (builtins.map
                  (netdev: { name = "10-${netdev}"; value = inputs.config.systemd.network.netdevs."10-${netdev}"; })
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
