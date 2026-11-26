{
  lib,
  ...
}:
{
  config = lib.mkMerge [
    # 固定接口命名
    (
      let
        links = {
          # lan1 (5GbE RTL8126, 更靠近 hdmi 口)
          "10-lan1" = {
            matchConfig = {
              PermanentMACAddress = "38:05:25:37:f8:69";
              Type = "ether";
            };
            linkConfig.Name = "lan1";
          };
          # lan2 (10GbE RTL8127, 更远离 hdmi 口)
          "10-lan2" = {
            matchConfig = {
              PermanentMACAddress = "38:05:25:37:f8:6a";
              Type = "ether";
            };
            linkConfig.Name = "lan2";
          };
        };
      in
      {
        boot.initrd.systemd.network.links = links;
        systemd.network.links = links;
      }
    )
    # 1. 启用 Fullcone NAT 的功能
    {
      nixpkgs.overlays = [
        (final: prev: {
          libnftnl = final.nur-xddxdd-prev.libnftnl-fullcone;
          nftables = final.nur-xddxdd-prev.nftables-fullcone;
        })
      ];
    }
    # 2. 应用 NAT、VLAN 接口及路由策略
    {
      systemd = {
        network = {
          netdevs = {
            "10-vlan10" = {
              netdevConfig = {
                Name = "lan1.10";
                Kind = "vlan";
              };
              vlanConfig.Id = 10;
            };
            "10-vlan20" = {
              netdevConfig = {
                Name = "lan1.20";
                Kind = "vlan";
              };
              vlanConfig.Id = 20;
            };
          };
          networks."10-lan1" = {
            matchConfig.Name = "lan1";
            vlan = [
              "lan1.10"
              "lan1.20"
            ];
          };
        };
      };
      nixos = {
        system.network.settings = {
          bridge.nixvirt.interfaces = [ "lan1.10" ];
          static = {
            nixvirt.ipv4 = {
              ip = "192.168.2.1";
              mask = 24;
            };
            "lan1.20".ipv4 = {
              ip = "192.168.3.1";
              mask = 24;
            };
          };
          trust = [
            "nixvirt"
            "lan1.20"
          ];
        };
        services.xray.client.v2ray-forwarder.asRouter = [ "lan1.20" ];
      };
      networking.nftables = {
        preCheckRuleset = ''
          sed -i 's/\bfullcone\b/masquerade/g' ruleset.conf
        '';
        tables = {
          fullcone_nat = {
            family = "inet";
            content = ''
              chain prerouting {
                type nat hook prerouting priority dstnat; policy accept;
                iifname "ppp0" fullcone
              }
              chain postrouting {
                type nat hook postrouting priority srcnat; policy accept;
                oifname "ppp0" fullcone
              }
            '';
          };
          hairpin = {
            family = "inet";
            content = ''
              chain prerouting {
                type nat hook prerouting priority dstnat; policy accept;
                iifname "nixvirt" fib daddr type local ip daddr != 192.168.2.0/24 dnat ip to 192.168.2.1
                iifname "lan1.20" fib daddr type local ip daddr != 192.168.3.0/24 dnat ip to 192.168.3.1
              }
              chain postrouting {
                type nat hook postrouting priority srcnat; policy accept;
                iifname "nixvirt" ip daddr 192.168.2.0/24 masquerade
                iifname "lan1.20" ip daddr 192.168.3.0/24 masquerade
              }
            '';
          };
        };
      };
    }
    # 3. DNS 和 DHCP
    {
      networking.firewall.allowedUDPPorts = [ 67 ];
      services.dnsmasq = {
        enable = true;
        resolveLocalQueries = false;
        settings = {
          # disable dns
          port = 0;
          interface = [
            "nixvirt"
            "lan1.20"
          ];
          bind-dynamic = true;
          dhcp-range = [
            "interface:nixvirt,192.168.2.100,192.168.2.250,255.255.255.0,12h"
            "interface:lan1.20,192.168.3.100,192.168.3.250,255.255.255.0,12h"
          ];
          dhcp-host = [
            "f8:c9:03:1d:8d:cf,192.168.2.209"
          ];
          dhcp-option = [
            "interface:nixvirt,option:dns-server,223.5.5.5"
            "interface:lan1.20,option:dns-server,192.168.3.1"
          ];
        };
      };
      # otherwise coredns may start before interface up
      systemd.services.coredns = {
        after = [ "sys-subsystem-net-devices-lan1.20.device" ];
        bindsTo = [ "sys-subsystem-net-devices-lan1.20.device" ];
      };
    }
  ];
}
