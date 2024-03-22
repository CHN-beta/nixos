inputs:
{
  options.nixos.system.networking = let inherit (inputs.lib) mkOption types; in
  {
    hostname = mkOption { type = types.nonEmptyStr; };
    networkManager.enable = mkOption
      { type = types.bool; default = inputs.config.nixos.system.networking.networkd == null; };
    networkd = mkOption
    {
      type = types.nullOr (types.submodule { options =
      {
        dhcp = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
        static = mkOption
        {
          type = types.attrsOf (types.submodule { options =
          {
            ip = mkOption { type = types.nonEmptyStr; };
            mask = mkOption { type = types.ints.unsigned; };
            gateway = mkOption { type = types.nonEmptyStr; };
            dns = mkOption { type = types.nonEmptyStr; default = null; };
          };});
          default = {};
        };
      };});
      default = null;
    };
    wireless = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
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
    (inputs.lib.mkIf (networking.networkd != null)
    {
      systemd.network =
      {
        enable = true;
        networks = builtins.listToAttrs
        (
          (builtins.map
            (network:
            {
              name = "10-${network.ssid}";
              value =
              {
                matchConfig.Name = network.ssid;
                networkConfig = { DHCP = "yes"; IPv6AcceptRA = true; };
                linkConfig.RequiredForOnline = "routable";
              };
            })
            networking.networkd.dhcp)
          ++ (builtins.map
            (network:
            {
              name = "10-${network.name}";
              value =
              {
                matchConfig.Name = network.name;
                address = [ "${network.ip}/${builtins.toString network.mask}" ];
                routes = [{ routeConfig.Gateway = network.gateway; }];
                linkConfig.RequiredForOnline = "routable";
              };
            })
            (inputs.localLib.attrsToList networking.networkd.static))
        );
      };
      networking =
      {
        networkmanager.unmanaged = with networking.networkd; dhcp ++ (builtins.attrNames static);
        useNetworkd = true;
      };
    })
    # wpa_supplicant
    (inputs.lib.mkIf (networking.wireless != [])
    {
      networking.wireless =
      {
        enable = true;
        networks = builtins.listToAttrs (builtins.map
          (network:
          {
            name = network;
            value.psk = "@${builtins.hashString "md5" network}_PSK@";
          })
          networking.wireless);
        environmentFile = inputs.config.sops.templates."wireless.env".path;
      };
      sops =
      {
        templates."wireless.env".content = builtins.concatStringsSep "\n" (builtins.map
          (network: "${builtins.hashString "md5" network}_PSK=${inputs.config.sops.placeholder."wireless/${network}"}")
          networking.wireless);
        secrets = builtins.listToAttrs (builtins.map
          (network: { name = "wireless/${network}"; value = {}; })
          networking.wireless);
      };
    })
  ];
}
