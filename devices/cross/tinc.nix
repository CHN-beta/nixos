inputs:
let
  inherit (inputs.topInputs.self.config.dns."chn.moe") getAddress;
  inherit (inputs.config.nixos.model) hostname;
  publicKey =
  {
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
    vps9 = "fCAqgs9VcYpTLccwFtSkx3dwMDG6787MQX4ycekxRSJ";
  };
  # 描述可以直接的设备之间的连接（图上的路径）。若一个设备可以主动接受连接，则设置它接受连接的 ip；否则设置为 null
  # 因为一条条路径描述起来比较麻烦，所以这里一次描述多条
  subnets =
  [
    # vps
    { device = inputs.lib.genAttrs [ "vps4" "vps6" "vps9" ] getAddress; distance = 1; }
    # 使用 vps9 代理的机器
    {
      device = (inputs.lib.genAttrs [ "srv1-node0" "srv2-node0" ] (_: null)) // { vps6 = getAddress "vps6"; };
      distance = 10;
    }
    # 使用 vps6 代理的机器
    { device = { vps6 = getAddress "vps6"; pc = null; }; distance = 10; }
    # 校内网络
    { device = (inputs.lib.genAttrs [ "srv1-node0" "srv2-node0" ] getAddress) // { nas = null; }; distance = 1; }
    # srv1 内部网络
    {
      device = inputs.lib.genAttrs' (builtins.genList (n: n) 3)
        (n: inputs.lib.nameValuePair "srv1-node${builtins.toString n}" "192.168.178.${builtins.toString (n + 1)}");
      distance = 1;
    }
    # srv2 内部网络
    {
      device = inputs.lib.genAttrs' (builtins.genList (n: n) 3)
        (n: inputs.lib.nameValuePair "srv2-node${builtins.toString n}" "192.168.178.${builtins.toString (n + 1)}");
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
      netToEdges = subnet: builtins.filter (v: v != null) (builtins.concatLists
        (inputs.lib.imap
          (i1: v1: inputs.lib.imap
            (i2: v2:
              if i2 <= i1 || (subnet.device.${v1} == null && subnet.device.${v2} == null) then null
              else { device = inputs.lib.genAttrs [ v1 v2 ] (v: subnet.device.${v}); inherit (subnet) distance; })
            (builtins.attrNames subnet.device))
          (builtins.attrNames subnet.device)));
      # 在一个图中加入一个边
      # current 的结构是：from.to = null or { address = xxx or null; length = xx; jump = xx; }
      addEdge = current: newEdge: builtins.mapAttrs
        (nameFrom: valueFrom: builtins.mapAttrs
          (nameTo: valueTo:
            # 不处理自己到自己的路
            if nameFrom == nameTo then null
            # 如果要加入的边包含起点
            else if newEdge.device ? "${nameFrom}" then
              # 如果要加入的边包含终点，那么这两个点可以直连
              if newEdge.device ? "${nameTo}"
                then { address = newEdge.device.${nameTo}; length = newEdge.distance; jump = nameTo; }
              else let edgePoint2 = builtins.head (inputs.lib.remove nameFrom (builtins.attrNames newEdge.device)); in
                # 如果边的另外一个点到终点可以连接
                if current.${edgePoint2}.${nameTo} != null then
                  # 如果之前不能连接，或者之前的连接比新的要长，则使用新的连接
                  if current.${nameFrom}.${nameTo} == null || (current.${nameFrom}.${nameTo}.length or 0
                    > newEdge.distance + current.${edgePoint2}.${nameTo}.length or 0) then
                  {
                    address = newEdge.device.${edgePoint2};
                    length = newEdge.distance + current.${edgePoint2}.${nameTo}.length;
                    jump = edgePoint2;
                  }
                  # 否则，不更新连接
                  else current.${nameFrom}.${nameTo}
                # 否则，不更新连接
                else current.${nameFrom}.${nameTo}
            # 如果要加入的边包不包含起点但包含终点
            else if newEdge.device ? "${nameTo}" then
              let edgePoint2 = builtins.head (inputs.lib.remove nameTo (builtins.attrNames newEdge.device)); in
              # 如果起点与另外一个点可以相连
              if current.${nameFrom}.${edgePoint2} != null then
                # 如果之前不能连接，或者新连接更短，则使用新的连接
                if current.${nameFrom}.${nameTo} == null || (current.${nameFrom}.${nameTo}.length or 0
                  > current.${nameFrom}.${edgePoint2}.length or 0 + newEdge.distance) then
                {
                  inherit (current.${nameFrom}.${edgePoint2}) address jump;
                  length = newEdge.distance + current.${nameFrom}.${edgePoint2}.length;
                }
                # 否则，不更新连接
                else current.${nameFrom}.${nameTo}
              # 如果起点与另外一个点不可以相连，则不改变连接
              else current.${nameFrom}.${nameTo}
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
                  else builtins.head (inputs.lib.sort (a: b: a.length < b.length)
                    [
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
                    ])
                # 如果正着不能连接、反过来可以连接，那么反过来连接一定是唯一的通路，使用反向的连接
                else if current.${nameFrom}.${p2} != null && current.${p1}.${nameTo} != null then
                {
                  inherit (current.${nameFrom}.${p2}) address jump;
                  length = current.${nameFrom}.${p2}.length + newEdge.distance + current.${p1}.${nameTo}.length;
                }
                # 如果正着连接、反向连接都不行，那么就不更新连接
                else current.${nameFrom}.${nameTo})
          valueFrom)
        current;
      # 初始时，所有点之间都不连接
      init = builtins.mapAttrs (_: _: builtins.mapAttrs (_: _: null) publicKey) publicKey;
    in builtins.foldl' addEdge init (inputs.lib.flatten (builtins.map netToEdges subnets));
  tincHostname = builtins.replaceStrings [ "-" ] [ "_" ];
in
{
  config = inputs.lib.mkIf (builtins.hasAttr hostname publicKey)
  {
    services.tinc.networks.tinc0 = 
    {
      settings = { Interface = "tinc0"; Name = tincHostname hostname; PingInterval = 10; };
      ed25519PrivateKeyFile = inputs.config.nixos.system.sops.secrets."tinc".path;
      hostSettings = inputs.lib.mkMerge
      [
        # 本机
        {
          "${tincHostname hostname}" =
          {
            settings.Ed25519PublicKey = publicKey.${hostname};
            subnets = [{ address = getAddress "tinc0.${hostname}"; weight = 0; }];
          };
        }
        (inputs.lib.mkMerge (inputs.lib.mapAttrsToList
          (n: v: { "${tincHostname v.jump}" = 
          {
            addresses = inputs.lib.optionals (v.address != null) [{ inherit (v) address; }];
            settings.Ed25519PublicKey = publicKey.${v.jump};
            subnets = [{ address = getAddress "tinc0.${n}"; weight = v.length; }];
          };})
          (inputs.lib.filterAttrs (_: v: v != null) connection.${hostname})))
      ];
    };
    nixos.system =
    {
      sops.secrets."tinc".owner = "tinc-tinc0";
      network.settings = inputs.lib.mkIf (inputs.config.nixos.system.network.implementation == "systemd-networkd")
        { static."tinc0" = { ip = getAddress "tinc0.${hostname}"; mask = 24; }; };
    };
    environment =
    {
      etc = inputs.lib.mkIf (inputs.config.nixos.system.network.implementation == "networkmanager")
      {
        "tinc/tinc0/tinc-up".source = inputs.pkgs.writeShellScript "tinc-up"
        ''
          ${inputs.pkgs.iproute2}/bin/ip link set $INTERFACE up
          ${inputs.pkgs.iproute2}/bin/ip addr add ${getAddress "tinc0.${hostname}"}/24 dev $INTERFACE
        '';
      };
      systemPackages = [ inputs.config.services.tinc.networks.tinc0.package ];
    };
    networking.firewall = { allowedTCPPorts = [ 655 ]; allowedUDPPorts = [ 655 ]; trustedInterfaces = [ "tinc0" ]; };
  };
}
