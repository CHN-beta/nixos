inputs:
let
  publicKey =
  {
    vps4 = "sUB97q3lPyGkFqPmjETzDP71J69ZVfaUTWs85+HA12g=";
    vps6 = "AVOsYUKQQCvo3ctst3vNi8XSVWo1Wh15066aHh+KpF4=";
    pc = "l1gFSDCeBxyf/BipXNvoEvVvLqPgdil84nmr5q6+EEw=";
    nas = "xCYRbZEaGloMk7Awr00UR3JcDJy4AzVp4QvGNoyEgFY=";
    srv1-node0 = "Br+ou+t9M9kMrnNnhTvaZi2oNFRygzebA1NqcHWADWM=";
    srv1-node1 = "wyNONnJF2WHykaHsQIV4gNntOaCsdTfi7ysXDsR2Bww=";
    srv1-node2 = "zWvkVyJwtQhwmxM2fHwNDnK+iwYm1O0RHrwCQ/VXdEo=";
    srv2-node0 = "lNTwQqaR0w/loeG3Fh5qzQevuAVXhKXgiPt6fZoBGFE=";
    srv2-node1 = "wc+DkY/WlGkLeI8cMcoRHcCcITNqX26P1v5JlkQwWSc=";
  };
  dns = inputs.topInputs.self.config.dns.wireguard;
  inherit (inputs.topInputs.self.config.dns."chn.moe") getAddress;
  listenPort =
  {
    wg0 = builtins.listToAttrs (builtins.map
      (name: inputs.lib.nameValuePair name 51820)
      (builtins.attrNames publicKey));
    wg1 = builtins.listToAttrs (builtins.map
      (name: inputs.lib.nameValuePair name (51820 + dns.peer.${name}))
      (builtins.attrNames publicKey));
  };
  subnet = # 设备之间可以直接连接的子网。若一个设备可以主动接受连接，则设置它接受连接的 ip；否则设置为 null
  {
    wg0 =
    [
      # 所有设备都可以连接到公网，但只有有公网 ip 的设备可以接受连接
      (builtins.listToAttrs
      (
        (builtins.map (n: inputs.lib.nameValuePair n (getAddress n)) [ "vps4" "vps6" ])
          ++ (builtins.map
            (n: { name = n; value = null; })
            (inputs.lib.subtractLists [ "vps4" "vps6" ] (builtins.attrNames publicKey)))
      ))
    ];
    wg1 =
    [
      # 所有设备都可以连接到公网，但只有有公网 ip 的设备可以接受连接
      (builtins.listToAttrs
      (
        (builtins.map (n: inputs.lib.nameValuePair n (getAddress n)) [ "vps4" "vps6" ])
          ++ (builtins.map (n: inputs.lib.nameValuePair n null) [ "pc" "nas" "srv1-node0" "srv2-node0" ])
      ))
      # 校内网络
      (builtins.listToAttrs
      (
        (builtins.map (n: inputs.lib.nameValuePair n (getAddress n)) [ "srv1-node0" "srv2-node0" ])
          ++ (builtins.map (n: inputs.lib.nameValuePair n null) [ "pc" "nas" ])
      ))
      # 办公室或者宿舍局域网
      (builtins.listToAttrs (builtins.map (n: inputs.lib.nameValuePair n (getAddress n)) [ "pc" "nas" ]))
      # 集群内部网络
      (builtins.listToAttrs (builtins.map
        (n: inputs.lib.nameValuePair "srv1-node${builtins.toString n}" "192.168.178.${builtins.toString (n + 1)}")
        (builtins.genList (n: n) 3)))
      (builtins.listToAttrs (builtins.map
        (n: inputs.lib.nameValuePair "srv2-node${builtins.toString n}" "192.168.178.${builtins.toString (n + 1)}")
        (builtins.genList (n: n) 2)))
    ];
  };
  # 给定起止点，返回最短路径的第一跳的目的地
  # 如果两个设备不能连接，返回 null;
  # 如果可以直接、主动连接，返回 { address = xx; port = xx; }；如果可以直接连接但是被动连接，返回 { address = null; }；
  # 如果需要中转，返回 { jump = 下一跳; }
  connection =
    let
      # 将给定子网翻译成一列边，返回 [{ dev1 = null or ip; dev2 = null or ip; }]
      # 边中至少有一个端点是可以接受连接的
      netToEdges = subnet:
        let devWithAddress = builtins.filter (n: subnet.${n} != null) (builtins.attrNames subnet);
        in inputs.lib.unique (builtins.concatLists (builtins.map
          (dev1: builtins.map
            (dev2: { "${dev1}" = subnet."${dev1}"; "${dev2}" = subnet."${dev2}"; })
            (inputs.lib.remove dev1 (builtins.attrNames subnet)))
          devWithAddress));
      # 在一个图中加入一个边
      # current 的结构是：from.to = null or { address = xxx or null; length = l; jump = ""; }
      addEdge = current: newEdge: builtins.mapAttrs
        (nameFrom: valueFrom: builtins.mapAttrs
          (nameTo: valueTo:
            # 不处理自己到自己的路
            if nameFrom == nameTo then null
            # 如果要加入的边包含起点
            else if newEdge ? "${nameFrom}" then
              # 如果要加入的边包含终点，那么这两个点可以直连
              if newEdge ? "${nameTo}"
                then { address = newEdge.${nameTo}; length = 1; }
                else let edgePoint2 = builtins.head (inputs.lib.remove nameFrom (builtins.attrNames newEdge)); in
                  # 如果边的另外一个点到终点可以连接
                  if current.${edgePoint2}.${nameTo} != null then
                    # 如果之前不能连接，则使用新的连接
                    if current.${nameFrom}.${nameTo} == null then
                      { jump = edgePoint2; length = 1 + current.${edgePoint2}.${nameTo}.length; }
                    # 如果之前可以连接，且新连接更短，同样更新连接
                    else if current.${nameFrom}.${nameTo}.length > 1 + current.${edgePoint2}.${nameTo}.length then
                      { jump = edgePoint2; length = 1 + current.${edgePoint2}.${nameTo}.length; }
                    # 否则，不更新连接
                    else current.${nameFrom}.${nameTo}
                  # 否则，不更新连接
                  else current.${nameFrom}.${nameTo}
            # 如果要加入的边包不包含起点但包含终点
            else if newEdge ? "${nameTo}" then
              let edgePoint2 = builtins.head (inputs.lib.remove nameTo (builtins.attrNames newEdge)); in
              # 如果起点与另外一个点可以相连
              if current.${nameFrom}.${edgePoint2} != null then
                # 如果之前不能连接，则使用新的连接
                if current.${nameFrom}.${nameTo} == null then
                {
                  jump = current.${nameFrom}.${edgePoint2}.jump or edgePoint2;
                  length = current.${nameFrom}.${edgePoint2}.length + 1;
                }
                # 如果之前可以连接，且新连接更短，同样更新连接
                else if current.${nameFrom}.${nameTo}.length > current.${nameFrom}.${edgePoint2}.length + 1 then
                {
                  jump = current.${nameFrom}.${edgePoint2}.jump or edgePoint2;
                  length = current.${nameFrom}.${edgePoint2}.length + 1;
                }
                # 否则，不更新连接
                else current.${nameFrom}.${nameTo}
              # 如果起点与另外一个点不可以相连，则不改变连接
              else current.${nameFrom}.${nameTo}
            # 如果要加入的边不包含起点和终点
            else
              let
                edgePoints = builtins.attrNames newEdge;
                p1 = builtins.elemAt edgePoints 0;
                p2 = builtins.elemAt edgePoints 1;
              in
                # 如果起点与边的第一个点可以连接、终点与边的第二个点可以连接
                if current.${nameFrom}.${p1} != null && current.${p2}.${nameTo} != null then
                  # 如果之前不能连接，则新连接必然是唯一的连接，使用新连接
                  if current.${nameFrom}.${nameTo} == null then
                  {
                    jump = current.${nameFrom}.${p1}.jump or p1;
                    length = current.${nameFrom}.${p1}.length + 1 + current.${p2}.${nameTo}.length;
                  }
                  # 如果之前可以连接，那么反过来一定也能连接，选取三种连接中最短的
                  else builtins.head (inputs.lib.sort
                    (a: b: if a == null then false else if b == null then true else a.length < b.length)
                    [
                      # 原先的连接
                      current.${nameFrom}.${nameTo}
                      # 正着连接
                      {
                        jump = current.${nameFrom}.${p1}.jump or p1;
                        length = current.${nameFrom}.${p1}.length + 1 + current.${p2}.${nameTo}.length;
                      }
                      # 反着连接
                      {
                        jump = current.${nameFrom}.${p2}.jump or p2;
                        length = current.${nameFrom}.${p2}.length + 1 + current.${p1}.${nameTo}.length;
                      }
                    ])
                # 如果正着不能连接、反过来可以连接，那么反过来连接一定是唯一的通路，使用反向的连接
                else if current.${nameFrom}.${p2} != null && current.${p1}.${nameTo} != null then
                {
                  jump = current.${nameFrom}.${p2}.jump or p2;
                  length = current.${nameFrom}.${p2}.length + 1 + current.${p1}.${nameTo}.length;
                }
                # 如果正着连接、反向连接都不行，那么就不更新连接
                else current.${nameFrom}.${nameTo})
          valueFrom)
        current;
      # 初始时，所有点之间都不连接
      init = builtins.listToAttrs (builtins.map
        (dev1:
        {
          name = dev1;
          value = builtins.listToAttrs (builtins.map
            (dev2: { name = dev2; value = null; })
            (builtins.attrNames publicKey));
        })
        (builtins.attrNames publicKey));
    in builtins.mapAttrs (_: v: builtins.foldl' addEdge init (builtins.concatLists (builtins.map netToEdges v))) subnet;
  networks = builtins.mapAttrs
    (n: v: builtins.listToAttrs (builtins.map
      (deviceName: inputs.lib.nameValuePair deviceName
      {
        ip = "192.168.${builtins.toString dns.net.${n}}.${builtins.toString dns.peer.${deviceName}}";
        listenPort = listenPort.${n}.${deviceName};
        peer = builtins.listToAttrs (builtins.concatLists (builtins.map
          (peerName:
            # 如果不能直连，就不用加 peer
            inputs.lib.optionals (v.${deviceName}.${peerName} ? address)
            [{
              name = peerName;
              value =
              {
                publicKey = publicKey.${peerName};
                allowedIPs =
                  [ "192.168.${builtins.toString dns.net.${n}}.${builtins.toString dns.peer.${peerName}}" ]
                  ++ builtins.map
                    (destination:
                      "192.168.${builtins.toString dns.net.${n}}.${builtins.toString dns.peer.${destination}}")
                    (builtins.filter
                      (destination: v.${deviceName}.${destination}.jump or null == peerName)
                      (builtins.attrNames publicKey));
              }
                // inputs.lib.optionalAttrs (v.${deviceName}.${peerName}.address != null)
                {
                  endpoint = "${v.${deviceName}.${peerName}.address}:"
                    + builtins.toString (listenPort.${n}.${peerName});
                };
            }])
          (inputs.lib.remove deviceName (builtins.attrNames publicKey))));
      })
      (builtins.attrNames publicKey))
    )
    connection;
in { config.nixos.services.wireguard = builtins.mapAttrs (_: v: v.${inputs.config.nixos.model.hostname}) networks; }
