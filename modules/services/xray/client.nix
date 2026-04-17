{ lib, flakeInputs, config, pkgs, ... }:
{
  options.nixos.services.xray.client = lib.mkOption
  {
    type = lib.types.nullOr (lib.types.submodule (submoduleInputs: { options =
    {
      xray =
      {
        serverAddress = lib.mkOption
        {
          type = lib.types.nonEmptyStr;
          default = flakeInputs.self.config.dns."chn.moe".getAddress "xserver3";
        };
      };
      coredns =
      {
        extraInterfaces = lib.mkOption { type = lib.types.listOf lib.types.nonEmptyStr; default = []; };
        hosts = lib.mkOption { type = lib.types.attrsOf lib.types.nonEmptyStr; default = {}; };
      };
      v2ray-forwarder.asRouter = lib.mkOption { type = lib.types.bool; default = false; };
    };}));
    default = null;
  };
  config = let inherit (config.nixos.services.xray) client; in lib.mkIf (client != null) (lib.mkMerge
  [
    # xray part
    {
      services.xray =
      {
        enable = true;
        package = pkgs.pkgs-unstable.xray;
        settingsFile = config.nixos.system.sops.templates."xray-client.json".path;
      };
      nixos.system.sops =
      {
        templates."xray-client.json" =
        {
          owner = config.users.users.v2ray.name;
          group = config.users.users.v2ray.group;
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
                    id = config.nixos.system.sops.placeholder."xray-client/uuid";
                    encryption = "none";
                  }];
                }];
                streamSettings =
                {
                  network = "xhttp";
                  security = "reality";
                  realitySettings =
                  {
                    serverName = "xserver3.chn.moe";
                    publicKey = "Nl0eVZoDF9d71_3dVsZGJl3UWR9LCv3B14gu7G6vhjk";
                    fingerprint = "firefox";
                  };
                  xhttpSettings.path = "/kT9hRk6D4gJ5WxNT";
                };
                tag = "proxy-vless";
              }
              { protocol = "freedom"; tag = "direct"; }
              { protocol = "dns"; tag = "dns-out"; }
              { protocol = "blackhole"; tag = "block"; }
            ];
            routing =
            {
              domainStrategy = "AsIs";
              rules = builtins.map (rule: rule // { type = "field"; })
              [
                { inboundTag = [ "dns-in" ]; outboundTag = "dns-out"; }
                {
                  inboundTag = [ "dns-internal" "common-in" "common-socks-in" ];
                  ip = [ "223.5.5.5" ];
                  outboundTag = "direct";
                }
                {
                  inboundTag = [ "dns-internal" "common-in" "common-socks-in" ];
                  ip = [ "8.8.8.8" "1.1.1.1" ];
                  outboundTag = "proxy-vless";
                }
                { inboundTag = [ "dns-internal" ]; outboundTag = "block"; }
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
      systemd.services.xray =
      {
        serviceConfig =
        {
          DynamicUser = lib.mkForce false;
          User = "v2ray";
          Group = "v2ray";
          CapabilityBoundingSet = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
          AmbientCapabilities = "CAP_NET_ADMIN CAP_NET_BIND_SERVICE";
          LimitNPROC = 65536;
          LimitNOFILE = 524288;
          CPUSchedulingPolicy = "rr";
        };
        restartTriggers = [ config.nixos.system.sops.templates."xray-client.json".file ];
      };
      users =
      {
        users.v2ray = { uid = config.nixos.user.uid.v2ray; group = "v2ray"; isSystemUser = true; };
        groups.v2ray.gid = config.nixos.user.gid.v2ray;
      };
      networking.firewall =
      {
        allowedTCPPortRanges = [{ from = 10880; to = 10884; }];
        allowedUDPPortRanges = [{ from = 10880; to = 10884; }];
      };
    }
    # dns part
    {
      services =
      {
        coredns =
        {
          enable = true;
          config =
            let
              hosts = pkgs.writeText "coredns.hosts" (builtins.concatStringsSep "\n"
                (lib.mapAttrsToList (n: v: "${v} ${n}") client.coredns.hosts));
            in
            ''
              . {
                log
                errors
                bind lo ${builtins.concatStringsSep " " client.coredns.extraInterfaces}
                hosts ${hosts} {
                  fallthrough
                }
                rewrite name exact git.chn.moe nas.ts.chn.moe
                forward . 127.0.0.1:10853
                cache 300 {
                  disable denial
                }
              }
            '';
        };
        resolved.enable = false;
      };
      environment.etc."resolv.conf".text = "nameserver 127.0.0.1";
      networking.firewall = { allowedTCPPorts = [ 53 ]; allowedUDPPorts = [ 53 ]; };
    }
    # transparent proxy part
    {
      systemd =
      {
        services.v2ray-forwarder = lib.mkIf (config.nixos.system.network.implementation == "networkmanager")
        {
          description = "v2ray-forwarder Daemon";
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = let ip = "${pkgs.iproute2}/bin/ip"; in
          {
            Type = "oneshot";
            RemainAfterExit = true;
            ExecStart = pkgs.writeShellScript "v2ray-forwarder.start"
            ''
              ${ip} rule add fwmark 1/1 table 100 priority 5000
              ${ip} route add local 0.0.0.0/0 dev lo table 100
            '';
            ExecStop = pkgs.writeShellScript "v2ray-forwarder.stop"
            ''
              ${ip} rule del fwmark 1/1 table 100 priority 5000
              ${ip} route del local 0.0.0.0/0 dev lo table 100
            '';
          };
        };
        network.networks."10-custom" = lib.mkIf (config.nixos.system.network.implementation == "systemd-networkd")
        {
          matchConfig.Name = "lo";
          routes = [{ Table = 100; Destination = "0.0.0.0/0"; Type = "local"; }];
          routingPolicyRules = [{ FirewallMark = "1/1"; Table = 100; Priority = 5000; }];
        };
      };
      networking.nftables.tables.v2ray =
      {
        family = "inet";
        content =
          let
            autoPort = "10880";
            proxyPort = "10883";
            loNet =
            [
              "0.0.0.0/8" "10.0.0.0/8" "100.64.0.0/10" "127.0.0.0/8" "169.254.0.0/16" "172.16.0.0/12"
              "192.0.0.0/24" "192.88.99.0/24" "192.168.0.0/16" "59.77.0.143" "198.18.0.0/15"
              "198.51.100.0/24" "203.0.113.0/24" "224.0.0.0/4" "240.0.0.0/4"
            ];
            loNetStr = builtins.concatStringsSep ", " loNet;
            noproxyUserStr = builtins.concatStringsSep ", " (builtins.map
              (user: builtins.toString config.nixos.user.uid.${user})
              [ "v2ray" "tailscale" ]);
          in
          ''
            set lo_net { type ipv4_addr; flags interval; elements = { ${loNetStr} }; }
            set noproxy_net { type ipv4_addr; flags interval; elements = { 223.5.5.5 }; }
            set noproxy_src_net { type ipv4_addr; flags interval; }
            set proxy_net { type ipv4_addr; flags interval; elements = { 8.8.8.8 }; }

            chain prerouting {
              type filter hook prerouting priority mangle; policy accept;
              meta l4proto != { tcp, udp } counter return

              # 对于目标地址为本机的新建的流，标记并永不代理
              fib daddr type local ct state new counter ct mark set ct mark | 1 return
              ct mark & 1 == 1 counter return

              # 如果不作为路由器使用，则可以返回那些没有被标记的流量
              ${if client.v2ray-forwarder.asRouter then "" else "meta mark & 1 == 0 counter return"}

              ip saddr @noproxy_src_net counter return
              ip daddr @noproxy_net counter return
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
              ip daddr @proxy_net counter meta mark set meta mark | 1 return
              ip daddr @lo_net counter return
              meta l4proto { tcp, udp } counter meta mark set meta mark | 1 return
              return
            }
          '';
      };
    }
  ]);
}
