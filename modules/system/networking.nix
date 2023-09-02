inputs:
{
  options.nixos.system.networking = let inherit (inputs.lib) mkOption types; in
  {
    hostname = mkOption { type = types.nonEmptyStr; };
  };
  config =
    let
      inherit (inputs.config.nixos.system) networking;
    in
    {
      networking =
      {
        networkmanager =
        {
          enable = true;
          # let networkmanager ignore the kernel command line `ip=xxx`
          extraConfig =
          ''
            [device]
            keep-configuration=no
          '';
        };
        hostName = networking.hostname;
      };
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
    };
}
