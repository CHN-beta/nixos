{
  lib,
  config,
  pkgs,
  ...
}:
let
  proxyUsingMap = {
    pc = "vps6";
    pe = "vps6";
    srv1-node0 = "vps10";
    srv1-node1 = "vps10";
    srv1-node2 = "vps10";
    srv2-node0 = "vps10";
    srv2-node1 = "vps10";
    srv2-node2 = "vps10";
    nas = "vps10";
  };
  proxyUsing = proxyUsingMap.${config.nixos.model.hostname} or null;
in
{
  options.nixos.services.xray.client = {
    enable = lib.mkOption {
      type = lib.types.bool;
      default = proxyUsing != null;
      readOnly = true;
    };
    coredns = {
      extraInterfaces = lib.mkOption {
        type = lib.types.listOf lib.types.nonEmptyStr;
        default = [ ];
      };
      hosts = lib.mkOption {
        type = lib.types.attrsOf lib.types.nonEmptyStr;
        default = { };
      };
    };
    v2ray-forwarder.asRouter = lib.mkOption {
      type = lib.types.oneOf [
        lib.types.bool
        (lib.types.listOf lib.types.nonEmptyStr)
      ];
      default = false;
    };
  };
  config =
    let
      inherit (config.nixos.services.xray) client;
    in
    lib.mkIf client.enable (
      lib.mkMerge [
        # xray part
        {
          services.xray = {
            enable = true;
            package = pkgs.xray;
            settingsFile = config.nixos.system.sops.templates."xray-client.json".path;
          };
          nixos.system.sops = {
            templates."xray-client.json" = {
              owner = config.users.users.v2ray.name;
              group = config.users.users.v2ray.group;
              content = builtins.toJSON {
                log.loglevel = "warning";
                dns = {
                  servers =
                    # try to match the domain list first, if matched successfully, use the first two dns for query.
                    # if matching the domain list fails, or matched successfully but the queried IP is not in the expected IP
                    #   list, then fallback to use the last two dns for query.
                    # here we use DoH GET instead of POST since 223.5.5.5 seems does not support DoH POST.
                    # see patch in buildNixpkgsConfig.
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
                      {
                        address = "https://223.5.5.5/dns-query";
                        expectIPs = [ "geoip:cn" ];
                      }
                      { address = "8.8.8.8"; }
                    ];
                  # use cache in coredns instead of xray
                  disableCache = true;
                  queryStrategy = "UseIPv4";
                  tag = "dns-internal";
                };
                inbounds = [
                  {
                    port = 10853;
                    protocol = "dokodemo-door";
                    settings = {
                      address = "8.8.8.8";
                      network = "tcp,udp";
                      port = 53;
                    };
                    tag = "dns-in";
                  }
                  {
                    port = 10880;
                    protocol = "dokodemo-door";
                    settings = {
                      network = "tcp,udp";
                      followRedirect = true;
                    };
                    streamSettings.sockopt.tproxy = "tproxy";
                    sniffing = {
                      enabled = true;
                      destOverride = [
                        "http"
                        "tls"
                        "quic"
                      ];
                      routeOnly = true;
                    };
                    tag = "common-in";
                  }
                  {
                    port = 10883;
                    protocol = "dokodemo-door";
                    settings = {
                      network = "tcp,udp";
                      followRedirect = true;
                    };
                    streamSettings.sockopt.tproxy = "tproxy";
                    tag = "proxy-in";
                  }
                  {
                    port = 10884;
                    protocol = "socks";
                    settings.udp = true;
                    tag = "proxy-socks-in";
                  }
                  {
                    port = 10882;
                    protocol = "socks";
                    settings.udp = true;
                    tag = "direct-in";
                  }
                  {
                    port = 10885;
                    protocol = "socks";
                    settings.udp = true;
                    sniffing = {
                      enabled = true;
                      destOverride = [
                        "http"
                        "tls"
                        "quic"
                      ];
                      routeOnly = true;
                    };
                    tag = "common-socks-in";
                  }
                ];
                outbounds = [
                  {
                    protocol = "vless";
                    settings.vnext = [
                      {
                        address = pkgs.localPkgs.getAddress proxyUsing;
                        port = 443;
                        users = [
                          {
                            id = config.nixos.system.sops.placeholder."xray-client/uuid";
                            encryption = "none";
                          }
                        ];
                      }
                    ];
                    streamSettings = {
                      network = "xhttp";
                      security = "reality";
                      realitySettings = {
                        serverName = "xserver3.chn.moe";
                        publicKey = "Nl0eVZoDF9d71_3dVsZGJl3UWR9LCv3B14gu7G6vhjk";
                        fingerprint = "firefox";
                      };
                      xhttpSettings.path = "/kT9hRk6D4gJ5WxNT";
                    };
                    tag = "vless";
                  }
                  {
                    protocol = "freedom";
                    tag = "direct";
                  }
                  {
                    protocol = "dns";
                    tag = "dns-out";
                  }
                  {
                    protocol = "blackhole";
                    tag = "block";
                  }
                ];
                routing = {
                  domainStrategy = "AsIs";
                  rules = builtins.map (rule: rule // { type = "field"; }) [
                    {
                      inboundTag = [ "dns-in" ];
                      outboundTag = "dns-out";
                    }
                    {
                      inboundTag = [
                        "dns-internal"
                        "common-in"
                        "common-socks-in"
                      ];
                      ip = [ "223.5.5.5" ];
                      outboundTag = "direct";
                    }
                    {
                      inboundTag = [
                        "dns-internal"
                        "common-in"
                        "common-socks-in"
                      ];
                      ip = [
                        "8.8.8.8"
                        "1.1.1.1"
                      ];
                      outboundTag = "vless";
                    }
                    {
                      inboundTag = [ "dns-internal" ];
                      outboundTag = "block";
                    }
                    {
                      inboundTag = [ "direct-in" ];
                      outboundTag = "direct";
                    }
                    {
                      inboundTag = [
                        "proxy-in"
                        "proxy-socks-in"
                      ];
                      outboundTag = "vless";
                    }
                    {
                      inboundTag = [
                        "common-in"
                        "common-socks-in"
                      ];
                      domain = [ "geosite:geolocation-cn" ];
                      outboundTag = "direct";
                    }
                    {
                      inboundTag = [
                        "common-in"
                        "common-socks-in"
                      ];
                      domain = [ "geosite:geolocation-!cn" ];
                      outboundTag = "vless";
                    }
                    {
                      inboundTag = [
                        "common-in"
                        "common-socks-in"
                      ];
                      ip = [
                        "geoip:cn"
                        "geoip:private"
                      ];
                      outboundTag = "direct";
                    }
                    {
                      inboundTag = [
                        "common-in"
                        "common-socks-in"
                      ];
                      outboundTag = "vless";
                    }
                  ];
                };
              };
            };
            secrets."xray-client/uuid" = { };
          };
          systemd.services.xray = {
            serviceConfig = {
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
          users = {
            users.v2ray = {
              uid = config.nixos.user.uid.v2ray;
              group = "v2ray";
              isSystemUser = true;
            };
            groups.v2ray.gid = config.nixos.user.gid.v2ray;
          };
          networking.firewall = {
            allowedTCPPortRanges = [
              {
                from = 10880;
                to = 10884;
              }
            ];
            allowedUDPPortRanges = [
              {
                from = 10880;
                to = 10884;
              }
            ];
          };
        }
        # dns part
        {
          services = {
            coredns = {
              enable = true;
              config =
                let
                  hosts = pkgs.writeText "coredns.hosts" (
                    builtins.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "${v} ${n}") client.coredns.hosts)
                  );
                in
                ''
                  . {
                    view a_aaaa {
                      expr type() == 'A' || type() == 'AAAA'
                    }
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
                  . {
                    view others
                    log
                    errors
                    bind lo ${builtins.concatStringsSep " " client.coredns.extraInterfaces}
                    forward . 223.5.5.5
                  }
                '';
            };
            resolved.enable = false;
          };
          environment.etc."resolv.conf".text = "nameserver 127.0.0.1";
          networking = {
            firewall = {
              allowedTCPPorts = [ 53 ];
              allowedUDPPorts = [ 53 ];
            };
            resolvconf.enable = false;
          };
          nixos.services.xray.client.coredns.extraInterfaces =
            lib.mkIf (lib.isList client.v2ray-forwarder.asRouter) client.v2ray-forwarder.asRouter;
        }
        # transparent proxy part
        {
          # three type of TCP/UDP stream should be considered:
          # 1. we are server (raised by other machine or us, destined to us).
          #     These stream should never be proxied, and will be marked with ct mark 1.
          # 2. we are client (raised by us, destined to other machine).
          #     These stream should be proxied, and the packet (not the stream) will be marked with fwmark 1,
          #     except some special cases.
          # 3. we are router (raised by other machine, destined to other machine).
          #     These stream should be proxied or not, depending on the usage scenario.
          # packets should be proxied will be marked with fwmark 1 then route to lo,
          #   and stream should not be proxied will be marked with ct mark 1.
          # note that ip rule should have higher priority than talescale (5270)
          systemd = {
            services.v2ray-forwarder =
              lib.mkIf (config.nixos.system.network.implementation == "networkmanager")
                {
                  description = "v2ray-forwarder Daemon";
                  after = [ "network.target" ];
                  wantedBy = [ "multi-user.target" ];
                  serviceConfig =
                    let
                      ip = "${pkgs.iproute2}/bin/ip";
                    in
                    {
                      Type = "oneshot";
                      RemainAfterExit = true;
                      ExecStart = pkgs.writeShellScript "v2ray-forwarder.start" ''
                        ${ip} rule add fwmark 1/1 table 100 priority 5000
                        ${ip} route add local 0.0.0.0/0 dev lo table 100
                        ${ip} -6 rule add fwmark 1/1 table 100 priority 5000
                        ${ip} -6 route add local ::/0 dev lo table 100
                      '';
                      ExecStop = pkgs.writeShellScript "v2ray-forwarder.stop" ''
                        ${ip} -6 rule del fwmark 1/1 table 100 priority 5000
                        ${ip} -6 route del local ::/0 dev lo table 100
                        ${ip} rule del fwmark 1/1 table 100 priority 5000
                        ${ip} route del local 0.0.0.0/0 dev lo table 100
                      '';
                    };
                };
            network.networks."10-custom" =
              lib.mkIf (config.nixos.system.network.implementation == "systemd-networkd")
                {
                  matchConfig.Name = "lo";
                  routes = [
                    {
                      Table = 100;
                      Destination = "0.0.0.0/0";
                      Type = "local";
                    }
                    {
                      Table = 100;
                      Destination = "::/0";
                      Type = "local";
                    }
                  ];
                  routingPolicyRules = [
                    {
                      FirewallMark = "1/1";
                      Table = 100;
                      Priority = 5000;
                    }
                  ];
                };
          };
          networking.nftables.tables.v2ray = {
            family = "inet";
            content =
              let
                autoPort = "10880";
                proxyPort = "10883";
                loNet4 = [
                  "0.0.0.0/8"
                  "10.0.0.0/8"
                  "100.64.0.0/10"
                  "127.0.0.0/8"
                  "169.254.0.0/16"
                  "172.16.0.0/12"
                  "192.0.0.0/24"
                  "192.88.99.0/24"
                  "192.168.0.0/16"
                  "59.77.0.143"
                  "198.18.0.0/15"
                  "198.51.100.0/24"
                  "203.0.113.0/24"
                  "224.0.0.0/4"
                  "240.0.0.0/4"
                ];
                loNet6 = [
                  "::1/128"
                  "fc00::/7"
                  "fe80::/10"
                ];
                loNet4Str = builtins.concatStringsSep ", " loNet4;
                loNet6Str = builtins.concatStringsSep ", " loNet6;
                noproxyUserStr = builtins.concatStringsSep ", " (
                  builtins.map (user: builtins.toString config.nixos.user.uid.${user}) [
                    "v2ray"
                    "tailscale"
                  ]
                );
              in
              ''
                set lo_net4 { type ipv4_addr; flags interval; elements = { ${loNet4Str} }; }
                set lo_net6 { type ipv6_addr; flags interval; elements = { ${loNet6Str} }; }
                set noproxy_net { type ipv4_addr; flags interval; elements = { 223.5.5.5 }; }
                set proxy_net { type ipv4_addr; flags interval; elements = { 8.8.8.8 }; }

                chain prerouting {
                  type filter hook prerouting priority mangle; policy accept;
                  meta l4proto != { tcp, udp } counter return

                  # stream destined to us should not be proxied
                  fib daddr type local ct state new counter ct mark set ct mark | 1 return
                  ct mark & 1 == 1 counter return

                  # The remaining packets are destined to other machines
                  # if it is raised by us, weather it should be proxied (packet type 2a) or not (packet type 2b)
                  #   should have been decided in the output chain and mark with fwmark 1 (2a) or not (2b)
                  # if it is raised by other machine (packet type 3), then we will here to decide whether to proxy it
                  # if it is not used as router, we should not proxy packet without fwmark 1 (2b and 3),
                  #   leaving only packet with fwmark 1 (2a) to be proxied
                  # otherwise, all packets will be leave for further decision
                  ${
                    if client.v2ray-forwarder.asRouter == false then
                      "meta mark & 1 == 0 counter return"
                    else if lib.isList client.v2ray-forwarder.asRouter then
                      "iifname != { ${
                        lib.concatStringsSep ", " (map (x: ''"${x}"'') client.v2ray-forwarder.asRouter)
                      } } meta mark & 1 == 0 counter return"
                    else
                      ""
                  }
                  ip daddr @noproxy_net counter return
                  ip daddr @proxy_net meta l4proto == { tcp, udp } counter \
                    tproxy ip to :${proxyPort} meta mark set meta mark | 1 return
                  ip daddr @lo_net4 counter return
                  ip6 daddr @lo_net6 counter return
                  meta l4proto == { tcp, udp } counter tproxy ip to :${autoPort} meta mark set meta mark | 1 return
                  return
                }

                chain output {
                  type route hook output priority mangle; policy accept;
                  meta l4proto != { tcp, udp } counter return

                  # stream destined to us should not be proxied
                  ct mark & 1 == 1 counter return

                  # remaining streams are raised by us and destined to other machines,
                  #   we should decide whether to proxy them or not
                  # for packet should be proxied, mark it with fwmark 1, it will then be handled by prerouting chain
                  meta skuid { ${noproxyUserStr} } counter return
                  ip daddr @noproxy_net counter return
                  ip daddr @proxy_net counter meta mark set meta mark | 1 return
                  ip daddr @lo_net4 counter return
                  ip6 daddr @lo_net6 counter return
                  counter meta mark set meta mark | 1 return
                  return
                }
              '';
          };
        }
      ]
    );
}
