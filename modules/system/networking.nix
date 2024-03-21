inputs:
{
  options.nixos.system.networking = let inherit (inputs.lib) mkOption types; in
  {
    hostname = mkOption { type = types.nonEmptyStr; };
    networkManager.enable = mkOption
      { type = types.bool; default = inputs.config.nixos.system.networking.networkd.dhcp == []; };
    networkd =
    {
      dhcp = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
    };
  };
  config = let inherit (inputs.config.nixos.system) networking; in inputs.lib.mkMerge
  [
    # general config
    {
      networking.hostName = networking.hostname;
      boot.kernel.sysctl =
      {
        "net.core.rmem_max" = 67108864;
        "net.core.wmem_max" = 67108864;
        "net.ipv4.tcp_rmem" = "4096 87380 67108864";
        "net.ipv4.tcp_wmem" = "4096 65536 67108864";
        "net.ipv4.tcp_mtu_probing" = true;
        "net.ipv4.tcp_tw_reuse" = true;
        "net.ipv4.tcp_max_syn_backlog" = 8388608;
        "net.core.netdev_max_backlog" = 8388608;
        "net.core.somaxconn" = 8388608;
        "net.ipv4.conf.all.route_localnet" = true;
        "net.ipv4.conf.default.route_localnet" = true;
        "net.ipv4.conf.all.accept_local" = true;
        "net.ipv4.conf.default.accept_local" = true;
        "net.ipv4.ip_forward" = true;
        "net.ipv4.ip_nonlocal_bind" = true;
        "net.bridge.bridge-nf-call-iptables" = false;
        "net.bridge.bridge-nf-call-ip6tables" = false;
        "net.bridge.bridge-nf-call-arptables" = false;
      };
    }
    # networkManager
    (inputs.lib.mkIf networking.networkManager.enable
    {
      networking.networkmanager =
      {
        enable = true;
        # let networkmanager ignore the kernel command line `ip=xxx`
        extraConfig =
        ''
          [device]
          keep-configuration=no
        '';
      };
    })
    # networkd
    (inputs.lib.mkIf (networking.networkd.dhcp != [])
    {
      systemd.network =
      {
        enable = true;
        networks = builtins.listToAttrs (builtins.map
          (network:
          {
            name = "10-${network}";
            value =
            {
              matchConfig.Name = network;
              networkConfig =
              {
                DHCP = "yes";
                IPv6AcceptRA = true;
              };
              linkConfig.RequiredForOnline = "routable";
            };
          })
          networking.networkd.dhcp);
      };
      networking = { useDHCP = false; networkmanager.unmanaged = networking.networkd.dhcp; };
    })
  ];
}
