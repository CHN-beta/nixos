inputs:
{
  options.nixos.system.network = let inherit (inputs.lib) mkOption types; in mkOption
  {
    # null: use network-manager; otherwise use networkd
    type = types.nullOr (types.submodule { options =
    {
      dhcp = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
      static = mkOption
      {
        type = types.attrsOf (types.submodule { options =
        {
          ip = mkOption { type = types.nonEmptyStr; };
          mask = mkOption { type = types.ints.unsigned; };
          gateway = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
          dns = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
        };});
        default = {};
      };
      bridge = mkOption
      {
        type = types.attrsOf (types.submodule { options =
        {
          interfaces = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
        };});
        default = {};
      };
      # wpa_passphrase SSID(wifi name) PSK(password)
      wireless = mkOption { type = types.nullOr (types.listOf types.nonEmptyStr); default = null; };
      trust = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
      masquerade = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
    };});
    default = null;
  };
  config = let inherit (inputs.config.nixos.system) network; in inputs.lib.mkMerge
  [
    # general config
    {
      boot.kernel.sysctl =
      {
        "net.core.rmem_max" = 67108864;
        "net.core.wmem_max" = 67108864;
        "net.ipv4.tcp_rmem" = "4096 87380 67108864";
        "net.ipv4.tcp_wmem" = "4096 65536 67108864";
        "net.ipv4.tcp_mtu_probing" = inputs.lib.mkDefault true;
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
        # lower tcp retransmission tries (5 times, about several seconds)
        "net.ipv4.tcp_retries2" = 5;
      };
      networking.nftables = { enable = true; flushRuleset = false; };
    }
    (inputs.localLib.mkConditional (network == null)
      {
        networking.networkmanager =
        {
          enable = true;
          settings.device.keep-configuration = "no";
        };
        environment.persistence."/nix/persistent".directories =
          [{ directory = "/etc/NetworkManager/system-connections"; mode = "0700"; }];
      }
      {
        systemd.network =
        {
          enable = true;
          networks = inputs.lib.mkMerge
          [
            (builtins.listToAttrs (builtins.map
              (network:
              {
                name = "10-${network}";
                value =
                {
                  matchConfig.Name = network;
                  networkConfig = { DHCP = "yes"; IPv6AcceptRA = true; };
                  linkConfig.RequiredForOnline = "routable";
                };
              })
              network.dhcp))
            (builtins.listToAttrs (builtins.map
              (network:
              {
                name = "10-${network.name}";
                value =
                {
                  matchConfig.Name = network.name;
                  address = [ "${network.value.ip}/${builtins.toString network.value.mask}" ];
                  routes = inputs.lib.mkIf (network.value.gateway != null)
                    [{ Gateway = network.value.gateway; Destination = "0.0.0.0/0"; }];
                  linkConfig.RequiredForOnline = "routable";
                  dns = inputs.lib.mkIf (network.value.dns != null) [ network.value.dns ];
                };
              })
              (inputs.localLib.attrsToList network.static)))
            (builtins.listToAttrs (builtins.map
              (network:
              {
                name = "10-${network.name}";
                value =
                {
                  matchConfig.Name = network.name;
                  bridgeConfig = {};
                  linkConfig.RequiredForOnline = "routable";
                };
              })
              (inputs.localLib.attrsToList network.bridge)))
            (builtins.listToAttrs (builtins.concatLists (builtins.map
              (bridge: builtins.map
                (network:
                {
                  name = "10-${network}";
                  value =
                  {
                    matchConfig.Name = network;
                    networkConfig.Bridge = bridge.name;
                    linkConfig.RequiredForOnline = "enslaved";
                  };
                }) bridge.value.interfaces)
              (inputs.localLib.attrsToList network.bridge))))
            (builtins.listToAttrs (builtins.map
              (network: { name = "10-${network}"; value.networkConfig.IPMasquerade = "both"; })
              network.masquerade))
          ];
          netdevs = builtins.listToAttrs (builtins.map
            (network: { name = "10-${network}"; value.netdevConfig = { Name = network; Kind = "bridge"; }; })
            (builtins.attrNames network.bridge));
        };
        networking =
        {
          useNetworkd = true;
          wireless = inputs.lib.mkIf (network.wireless != null)
          {
            enable = true;
            # wpa_passphrase SSID password
            networks = builtins.listToAttrs (builtins.map
              (network: { name = network; value.pskRaw = "ext:${network}"; }) network.wireless);
            secretsFile = inputs.config.sops.templates."wireless.env".path;
          };
          firewall.trustedInterfaces = network.trust;
        };
        # dnsable dns fallback, use provided dns servers or no dns
        services.resolved.fallbackDns = [];
        sops = inputs.lib.mkIf (network.wireless != null)
        {
          templates."wireless.env".content = builtins.concatStringsSep "\n" (builtins.map
            (network: "${network}=${inputs.config.sops.placeholder."wireless/${network}"}")
            network.wireless);
          secrets = builtins.listToAttrs (builtins.map
            (network: { name = "wireless/${network}"; value = {}; })
            network.wireless);
        };
    })
  ];
}
