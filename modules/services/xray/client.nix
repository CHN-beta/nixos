inputs:
{
  options.nixos.services.xray.client = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule (submoduleInputs: { options =
    {
      xray =
      {
        serverName = mkOption { type = types.nonEmptyStr; default = "xserver2.chn.moe"; };
        serverAddress = mkOption
        {
          type = types.nonEmptyStr;
          default = inputs.topInputs.self.config.dns."chn.moe".getAddress
            (inputs.lib.removeSuffix ".chn.moe" submoduleInputs.config.xray.serverName);
        };
      };
      dnsmasq =
      {
        extraInterfaces = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
        hosts = mkOption { type = types.attrsOf types.nonEmptyStr; default = {}; };
      };
    };}));
    default = null;
  };
  config = let inherit (inputs.config.nixos.services.xray) client; in inputs.lib.mkIf (client != null)
  {
    services =
    {
      dnsmasq =
      {
        enable = true;
        settings =
        {
          no-poll = true;
          log-queries = true;
          server = [ "127.0.0.1#10853" ];
          interface = client.dnsmasq.extraInterfaces ++ [ "lo" ];
          bind-dynamic = true;
          address = builtins.map (host: "/${host.name}/${host.value}")
            (inputs.localLib.attrsToList client.dnsmasq.hosts);
        };
      };
      resolved.enable = false;
    };
    nixos.system.sops =
    {
      templates."xray-client.json" =
      {
        owner = inputs.config.users.users.v2ray.name;
        group = inputs.config.users.users.v2ray.group;
        content = builtins.toJSON
        {
          log.loglevel = "warning";
          dns =
          {
            servers =
            # 先尝试匹配域名列表进行查询，若匹配成功则使用前两个 dns 查询。
            # 若匹配域名列表失败，或者匹配成功但是查询到的 IP 不在期望的 IP 列表中，则回落到使用后两个 dns 依次查询。
            [
              {
                address = "https://223.5.5.5/dns-query";
                domains = [ "geosite:geolocation-cn" ];
                expectIPs = [ "geoip:cn" ];
                skipFallback = true;
              }
              {
                address = "8.8.8.8";
                domains = [ "geosite:geolocation-!cn" ];
                expectIPs = [ "geoip:!cn" ];
                skipFallback = true;
              }
              { address = "https://223.5.5.5/dns-query"; expectIPs = [ "geoip:cn" ]; }
              { address = "8.8.8.8"; }
            ];
            disableCache = true;
            queryStrategy = "UseIPv4";
            tag = "dns-internal";
          };
          inbounds =
          [
            {
              port = 10853;
              protocol = "dokodemo-door";
              settings = { address = "8.8.8.8"; network = "tcp,udp"; port = 53; };
              tag = "dns-in";
            }
            {
              port = 10880;
              protocol = "dokodemo-door";
              settings = { network = "tcp,udp"; followRedirect = true; };
              streamSettings.sockopt.tproxy = "tproxy";
              sniffing = { enabled = true; destOverride = [ "http" "tls" "quic" ]; routeOnly = true; };
              tag = "common-in";
            }
            {
              port = 10881;
              protocol = "dokodemo-door";
              settings = { network = "tcp,udp"; followRedirect = true; };
              streamSettings.sockopt.tproxy = "tproxy";
              tag = "xmu-in";
            }
            {
              port = 10883;
              protocol = "dokodemo-door";
              settings = { network = "tcp,udp"; followRedirect = true; };
              streamSettings.sockopt.tproxy = "tproxy";
              tag = "proxy-in";
            }
            { port = 10884; protocol = "socks"; settings.udp = true; tag = "proxy-socks-in"; }
            { port = 10882; protocol = "socks"; settings.udp = true; tag = "direct-in"; }
            {
              port = 10885;
              protocol = "socks";
              settings.udp = true;
              sniffing = { enabled = true; destOverride = [ "http" "tls" "quic" ]; routeOnly = true; };
              tag = "common-socks-in";
            }
          ];
          outbounds =
          [
            {
              protocol = "vless";
              settings.vnext =
              [{
                address = client.xray.serverAddress;
                port = 443;
                users =
                [{
                  id = inputs.config.nixos.system.sops.placeholder."xray-client/uuid";
                  encryption = "none";
                  flow = "xtls-rprx-vision-udp443";
                }];
              }];
              streamSettings =
              {
                network = "raw";
                security = "reality";
                realitySettings =
                {
                  inherit (client.xray) serverName;
                  publicKey = "Nl0eVZoDF9d71_3dVsZGJl3UWR9LCv3B14gu7G6vhjk";
                  fingerprint = "firefox";
                };
              };
              tag = "proxy-vless";
            }
            { protocol = "freedom"; tag = "direct"; }
            { protocol = "dns"; tag = "dns-out"; }
            {
              protocol = "socks";
              settings.servers = [{ address = "127.0.0.1"; port = 10069; }];
              tag = "xmu-out";
            }
            { protocol = "blackhole"; tag = "block"; }
          ];
          routing =
          {
            domainStrategy = "AsIs";
            rules = builtins.map (rule: rule // { type = "field"; })
            [
              { inboundTag = [ "dns-in" ]; outboundTag = "dns-out"; }
              { inboundTag = [ "dns-internal" ]; ip = [ "223.5.5.5" ]; outboundTag = "direct"; }
              { inboundTag = [ "dns-internal" ]; ip = [ "8.8.8.8" ]; outboundTag = "proxy-vless"; }
              { inboundTag = [ "dns-internal" ]; outboundTag = "block"; }
              { inboundTag = [ "xmu-in" ]; outboundTag = "xmu-out"; }
              { inboundTag = [ "direct-in" ]; outboundTag = "direct"; }
              { inboundTag = [ "proxy-in" "proxy-socks-in" ]; outboundTag = "proxy-vless"; }
              {
                inboundTag = [ "common-in" "common-socks-in" ];
                domain = [ "geosite:geolocation-cn" ];
                outboundTag = "direct";
              }
              {
                inboundTag = [ "common-in" "common-socks-in" ];
                domain = [ "geosite:geolocation-!cn" ];
                outboundTag = "proxy-vless";
              }
              {
                inboundTag = [ "common-in" "common-socks-in" ];
                ip = [ "geoip:cn" "geoip:private" ];
                outboundTag = "direct";
              }
              { inboundTag = [ "common-in" "common-socks-in" ]; outboundTag = "proxy-vless"; }
            ];
          };
        };
      };
      secrets."xray-client/uuid" = {};
    };
    systemd =
    {
      services = inputs.lib.mkMerge
      [
        {
          xray-client =
          {
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            script = let config = inputs.config.nixos.system.sops.templates."xray-client.json".path; in
              "exec ${inputs.pkgs.xray}/bin/xray -config ${config}";
            serviceConfig =
            {
              User = "v2ray";
              Group = "v2ray";
              CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
              AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
              NoNewPrivileges = true;
              LimitNPROC = 65536;
              LimitNOFILE = 524288;
              CPUSchedulingPolicy = "rr";
            };
            restartTriggers = [ inputs.config.nixos.system.sops.templates."xray-client.json".file ];
          };
        }
        (inputs.lib.mkIf (inputs.config.nixos.system.network.implementation == "networkmanager")
        {
          v2ray-forwarder =
          {
            description = "v2ray-forwarder Daemon";
            after = [ "network.target" ];
            wantedBy = [ "multi-user.target" ];
            serviceConfig = let ip = "${inputs.pkgs.iproute2}/bin/ip"; in
            {
              Type = "oneshot";
              RemainAfterExit = true;
              ExecStart = inputs.pkgs.writeShellScript "v2ray-forwarder.start"
              ''
                ${ip} rule add fwmark 1/1 table 100 priority 5000
                ${ip} route add local 0.0.0.0/0 dev lo table 100
              '';
              ExecStop = inputs.pkgs.writeShellScript "v2ray-forwarder.stop"
              ''
                ${ip} rule del fwmark 1/1 table 100 priority 5000
                ${ip} route del local 0.0.0.0/0 dev lo table 100
              '';
            };
          };
        })
      ];
      network.networks = inputs.lib.mkIf (inputs.config.nixos.system.network.implementation == "systemd-networkd")
      {
        "10-custom" =
        {
          matchConfig.Name = "lo";
          routes = [{ Table = 100; Destination = "0.0.0.0/0"; Type = "local"; }];
          routingPolicyRules = [{ FirewallMark = "1/1"; Table = 100; Priority = 5000; }];
        };
      };
    };
    users =
    {
      users.v2ray = { uid = inputs.config.nixos.user.uid.v2ray; group = "v2ray"; isSystemUser = true; };
      groups.v2ray.gid = inputs.config.nixos.user.gid.v2ray;
    };
    environment.etc."resolv.conf".text = "nameserver 127.0.0.1";
    networking =
    {
      nftables.tables.v2ray =
      {
        family = "inet";
        content =
          let
            autoPort = "10880";
            xmuPort = "10881";
            proxyPort = "10883";
            loNet =
            [
              "0.0.0.0/8" "10.0.0.0/8" "100.64.0.0/10" "127.0.0.0/8" "169.254.0.0/16" "172.16.0.0/12"
              "192.0.0.0/24" "192.88.99.0/24" "192.168.0.0/16" "59.77.0.143" "198.18.0.0/15"
              "198.51.100.0/24" "203.0.113.0/24" "224.0.0.0/4" "240.0.0.0/4"
            ];
            loNetStr = builtins.concatStringsSep ", " loNet;
            noproxyUserStr = builtins.concatStringsSep ", " (builtins.map
              (user: builtins.toString inputs.config.nixos.user.uid.${user})
              [ "v2ray" "tailscale" ]);
          in
          ''
            set lo_net { type ipv4_addr; flags interval; elements = { ${loNetStr} }; }
            set xmu_net { type ipv4_addr; flags interval; }
            set noproxy_net { type ipv4_addr; flags interval; elements = { 223.5.5.5 }; }
            set noproxy_src_net { type ipv4_addr; flags interval; }
            set proxy_net { type ipv4_addr; flags interval; elements = { 8.8.8.8 }; }

            chain prerouting {
              type filter hook prerouting priority mangle; policy accept;
              meta l4proto != { tcp, udp } counter return

              # 对于目标地址为本机的新建的流，标记并永不代理
              fib daddr type local ct state new counter ct mark set ct mark | 1 return
              ct mark & 1 == 1 counter return

              ip saddr @noproxy_src_net counter return
              ip daddr @noproxy_net counter return
              ip saddr != 172.16.0.0/12 ip daddr @xmu_net meta l4proto { tcp, udp } counter \
                tproxy ip to :${xmuPort} meta mark set meta mark | 1 return
              ip daddr @proxy_net meta l4proto { tcp, udp } counter tproxy ip to :${proxyPort} \
                meta mark set meta mark | 1 return
              ip daddr @lo_net counter return
              meta l4proto { tcp, udp } counter tproxy ip to :${autoPort} meta mark set meta mark | 1 return
              return
            }

            chain output {
              type route hook output priority mangle; policy accept;
              ct mark & 1 == 1 counter return
              meta skuid { ${noproxyUserStr} } counter return

              ip saddr @noproxy_src_net counter return
              ip daddr @noproxy_net counter return
              ip daddr @xmu_net counter meta mark set meta mark | 1 return
              ip daddr @proxy_net counter meta mark set meta mark | 1 return
              ip daddr @lo_net counter return
              meta l4proto { tcp, udp } counter meta mark set meta mark | 1 return
              return
            }
          '';
      };
      firewall =
      {
        allowedTCPPorts = [ 53 ];
        allowedUDPPorts = [ 53 ];
        allowedTCPPortRanges = [{ from = 10880; to = 10884; }];
        allowedUDPPortRanges = [{ from = 10880; to = 10884; }];
      };
    };
  };
}
