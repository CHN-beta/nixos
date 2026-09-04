{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (pkgs.localPkgs) getAddress;
  inherit (config.nixos.model) hostname;
  publicKey = {
    nas = "sSN3eeBgrMXF6/XYfEBe54TXmfHETOESX+SyrpGlmDK";
    pc = "soafMZ/0EViMhKYNc8g8pp4sbhR/2HnnXwGQln0BgCK";
    srv1-node0 = "ZKUwi386ZssXLQGORUzlRxof7NhXigUw3QZHAP0Pb8N";
    srv1-node1 = "5eti59LrOMejEWYDxOYrh7SD93nLMSH+iX7vaBN4BrE";
    srv1-node2 = "e6jW9g4QY357ocMRoW4P0s6UHAspvKJzmAGb/WT1a+H";
    srv2-node0 = "zTv+o7K2SpcPp9YLrPe8iJqCunrCiJyqz13fXcDouEH";
    srv2-node1 = "sk/w+GBrt0lzkTZ3y3vZ/eHKNrG8X95eqR9IuhCFYwB";
    srv2-node2 = "csZoiTwZItonm6h+uqkJ5z9J6o1iFlBESQ2u97Wz2JL";
    vps4 = "N03OoCyj4ADkeN3cimJI/bJrBw8g1kz3TJ+1BTe+oyA";
    vps6 = "rYOCGG+B4isTifKJQqsEdfhQuQRnUiIsvz7uI7vZiDN";
    vps10 = "ojNWDzYxt9VhWT5rDhiMOiFALzabJ0URg+tB5yfnEUN";
    pe = "h09nsWrcO55qndZmayePfWZjgwjv2aXbKnpFE9lUsfP";
    ddml-dev-vm = "grPTW5etegFdONUYWhhkuRyp+i+h+5LuGNV4eiHiA1H";
    ddml-vm = "h317Y+NcMAXWPQlTCAurdU+mTdIAs9aDZc+2mrChFyK";
  };
  # 描述可以直接的设备之间的连接（图上的路径）。若一个设备可以主动接受连接，则设置它接受连接的 ip；否则设置为 null
  # 因为一条条路径描述起来比较麻烦，所以这里一次描述多条
  subnets = [
    # vps
    {
      device = lib.genAttrs [ "vps4" "vps6" "vps10" ] getAddress;
      distance = 1;
    }
    # 使用 vps10 代理的机器
    {
      device = (lib.genAttrs [ "srv1-node0" "srv2-node0" "nas" "ddml-dev-vm" ] (_: null)) // {
        vps10 = getAddress "vps10";
      };
      distance = 10;
    }
    # 使用 vps6 代理的机器
    {
      device = {
        vps6 = getAddress "vps6";
        pc = null;
        pe = null;
      };
      distance = 10;
    }
    # 运行在nas上的虚拟机
    {
      device = {
        nas = "192.168.122.1";
        ddml-vm = null;
      };
      distance = 1;
    }
    # 国内网络
    {
      device = (lib.genAttrs [ "srv1-node0" "srv2-node0" "pc" "pe"  ] (_: null)) // {
        nas = "nas.chn.moe";
      };
      distance = 3;
    }
    # 校内网络
    {
      device = (lib.genAttrs [ "srv1-node0" "srv2-node0" ] getAddress);
      distance = 1;
    }
    # srv1 内部网络
    {
      device = lib.genAttrs' (builtins.genList (n: n) 3) (
        n: lib.nameValuePair "srv1-node${builtins.toString n}" "192.168.178.${builtins.toString (n + 1)}"
      );
      distance = 1;
    }
    # srv2 内部网络
    {
      device = lib.genAttrs' (builtins.genList (n: n) 3) (
        n: lib.nameValuePair "srv2-node${builtins.toString n}" "192.168.178.${builtins.toString (n + 1)}"
      );
      distance = 1;
    }
  ];
  # 给定起止点，返回最短路径的第一跳的目的地，以及总路程长度
  # 结构是：from.to = null or { address = xxx or null; length = xx; jump = xx; }
  # 如果两个设备不能连接，返回 null;
  # 如果可以主动连接，返回 { address = xxx; length = xx; jump = xx; }；
  # 如果只可以被动连接，返回 { address = null; length = xx; jump = xx; }；
  connection =
    let
      # 将给定子网翻译成一列边，返回 [{ device = { dev1 = null or ip; dev2 = null or ip; }; distance = xxx; }]
      # 边中至少有一个端点是可以接受连接的
      netToEdges =
        subnet:
        builtins.filter (v: v != null) (
          builtins.concatLists (
            lib.imap (
              i1: v1:
              lib.imap (
                i2: v2:
                if i2 <= i1 || (subnet.device.${v1} == null && subnet.device.${v2} == null) then
                  null
                else
                  {
                    device = lib.genAttrs [ v1 v2 ] (v: subnet.device.${v});
                    inherit (subnet) distance;
                  }
              ) (builtins.attrNames subnet.device)
            ) (builtins.attrNames subnet.device)
          )
        );
      # 在一个图中加入一个边
      # current 的结构是：from.to = null or { address = xxx or null; length = xx; jump = xx; }
      addEdge =
        current: newEdge:
        builtins.mapAttrs (
          nameFrom: valueFrom:
          builtins.mapAttrs (
            nameTo: valueTo:
            # 不处理自己到自己的路
            if nameFrom == nameTo then
              null
            # 如果要加入的边包含起点
            else if newEdge.device ? "${nameFrom}" then
              # 如果要加入的边包含终点，那么这两个点可以直连
              if newEdge.device ? "${nameTo}" then
                {
                  address = newEdge.device.${nameTo};
                  length = newEdge.distance;
                  jump = nameTo;
                }
              else
                let
                  edgePoint2 = builtins.head (lib.remove nameFrom (builtins.attrNames newEdge.device));
                in
                # 如果边的另外一个点到终点可以连接
                if current.${edgePoint2}.${nameTo} != null then
                  # 如果之前不能连接，或者之前的连接比新的要长，则使用新的连接
                  if
                    current.${nameFrom}.${nameTo} == null
                    || (
                      current.${nameFrom}.${nameTo}.length or 0
                      > newEdge.distance + current.${edgePoint2}.${nameTo}.length or 0
                    )
                  then
                    {
                      address = newEdge.device.${edgePoint2};
                      length = newEdge.distance + current.${edgePoint2}.${nameTo}.length;
                      jump = edgePoint2;
                    }
                  # 否则，不更新连接
                  else
                    current.${nameFrom}.${nameTo}
                # 否则，不更新连接
                else
                  current.${nameFrom}.${nameTo}
            # 如果要加入的边包不包含起点但包含终点
            else if newEdge.device ? "${nameTo}" then
              let
                edgePoint2 = builtins.head (lib.remove nameTo (builtins.attrNames newEdge.device));
              in
              # 如果起点与另外一个点可以相连
              if current.${nameFrom}.${edgePoint2} != null then
                # 如果之前不能连接，或者新连接更短，则使用新的连接
                if
                  current.${nameFrom}.${nameTo} == null
                  || (
                    current.${nameFrom}.${nameTo}.length or 0
                    > current.${nameFrom}.${edgePoint2}.length or 0 + newEdge.distance
                  )
                then
                  {
                    inherit (current.${nameFrom}.${edgePoint2}) address jump;
                    length = newEdge.distance + current.${nameFrom}.${edgePoint2}.length;
                  }
                # 否则，不更新连接
                else
                  current.${nameFrom}.${nameTo}
              # 如果起点与另外一个点不可以相连，则不改变连接
              else
                current.${nameFrom}.${nameTo}
            # 如果要加入的边不包含起点和终点
            else
              let
                edgePoints = builtins.attrNames newEdge.device;
                p1 = builtins.elemAt edgePoints 0;
                p2 = builtins.elemAt edgePoints 1;
              in
              # 如果起点与边的第一个点可以连接、终点与边的第二个点可以连接
              if current.${nameFrom}.${p1} != null && current.${p2}.${nameTo} != null then
                # 如果之前不能连接，则新连接必然是唯一的连接，使用新连接
                if current.${nameFrom}.${nameTo} == null then
                  {
                    inherit (current.${nameFrom}.${p1}) address jump;
                    length = current.${nameFrom}.${p1}.length + newEdge.distance + current.${p2}.${nameTo}.length;
                  }
                # 如果之前可以连接，那么反过来一定也能连接，选取三种连接中最短的
                else
                  builtins.head (
                    lib.sort (a: b: a.length < b.length) [
                      # 原先的连接
                      current.${nameFrom}.${nameTo}
                      # 正着连接
                      {
                        inherit (current.${nameFrom}.${p1}) address jump;
                        length = current.${nameFrom}.${p1}.length + newEdge.distance + current.${p2}.${nameTo}.length;
                      }
                      # 反着连接
                      {
                        inherit (current.${nameFrom}.${p2}) address jump;
                        length = current.${nameFrom}.${p2}.length + newEdge.distance + current.${p1}.${nameTo}.length;
                      }
                    ]
                  )
              # 如果正着不能连接、反过来可以连接，那么反过来连接一定是唯一的通路，使用反向的连接
              else if current.${nameFrom}.${p2} != null && current.${p1}.${nameTo} != null then
                {
                  inherit (current.${nameFrom}.${p2}) address jump;
                  length = current.${nameFrom}.${p2}.length + newEdge.distance + current.${p1}.${nameTo}.length;
                }
              # 如果正着连接、反向连接都不行，那么就不更新连接
              else
                current.${nameFrom}.${nameTo}
          ) valueFrom
        ) current;
      # 初始时，所有点之间都不连接
      init = builtins.mapAttrs (_: _: builtins.mapAttrs (_: _: null) publicKey) publicKey;
    in
    builtins.foldl' addEdge init (lib.flatten (builtins.map netToEdges subnets));
  tincHostname = builtins.replaceStrings [ "-" ] [ "_" ];
in
{
  config = lib.mkIf (builtins.hasAttr hostname publicKey) {
    services.tinc.networks.tinc0 = {
      settings = {
        Interface = "tinc0";
        Name = tincHostname hostname;
        Proxy = lib.mkIf (config.nixos.services.xray.client.enable) "socks5 127.0.0.1 10885";
        ConnectTo = builtins.map tincHostname (
          builtins.attrNames (
            lib.filterAttrs (n: v: (v.address or null != null) && (v.jump or null == n)) connection.${hostname}
          )
        );
        AutoConnect = false;
        TunnelServer = true;
      };
      ed25519PrivateKeyFile = config.nixos.system.sops.secrets."tinc".path;
      hostSettings = lib.mkMerge [
        # 本机
        {
          "${tincHostname hostname}" = {
            settings.Ed25519PublicKey = publicKey.${hostname};
            subnets = [
              {
                address = getAddress "tinc0.${hostname}";
                weight = 0;
              }
            ];
          };
        }
        (lib.mkMerge (
          lib.mapAttrsToList (n: v: {
            "${tincHostname v.jump}" = {
              addresses = lib.optionals (v.address != null) [ { inherit (v) address; } ];
              settings = {
                Ed25519PublicKey = publicKey.${v.jump};
                IndirectData = true;
              };
              subnets = [
                {
                  address = getAddress "tinc0.${n}";
                  # 最短路径已经被提前计算出来了，这里将权重统一设置为零
                  # 如果分开设置，两个节点会因为对权重的描述不统一而拒绝连接
                  weight = 0;
                }
              ];
            };
          }) (lib.filterAttrs (_: v: v != null) connection.${hostname})
        ))
      ];
    };
    nixos.system = {
      sops.secrets."tinc".owner = "tinc-tinc0";
      network.settings = lib.mkIf (config.nixos.system.network.implementation == "systemd-networkd") {
        static."tinc0".ipv4 = {
          ip = getAddress "tinc0.${hostname}";
          mask = 24;
        };
      };
    };
    environment = {
      etc = lib.mkIf (config.nixos.system.network.implementation == "networkmanager") {
        "tinc/tinc0/tinc-up".source = pkgs.writeShellScript "tinc-up" ''
          ${pkgs.iproute2}/bin/ip link set $INTERFACE up
          ${pkgs.iproute2}/bin/ip addr add ${getAddress "tinc0.${hostname}"}/24 dev $INTERFACE
        '';
      };
      systemPackages = [ config.services.tinc.networks.tinc0.package ];
    };
    networking.firewall = {
      allowedTCPPorts = [ 655 ];
      allowedUDPPorts = [ 655 ];
      trustedInterfaces = [ "tinc0" ];
    };
    systemd.services =
      connection.${hostname}
      |> lib.filterAttrs (n: v: (v.address or null != null) && (v.jump or null == n))
      |> lib.mapAttrs' (
        n: v:
        lib.nameValuePair "tinc-ping-${n}" {
          after = [ "network.target" ];
          wantedBy = [ "multi-user.target" ];
          serviceConfig = {
            ExecStart = "${pkgs.iputils}/bin/ping -i 5 tinc0.${n}.chn.moe";
            Restart = "always";
            RestartSec = 5;
          };
          unitConfig.StartLimitIntervalSec = 0;
        }
      );
  };
}
