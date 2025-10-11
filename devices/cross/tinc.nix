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
    vps4 = "N03OoCyj4ADkeN3cimJI/bJrBw8g1kz3TJ+1BTe+oyA";
    vps6 = "rYOCGG+B4isTifKJQqsEdfhQuQRnUiIsvz7uI7vZiDN";
  };
  nodes =
  [
    # 工位网络
    { to = "nas"; from = { pc = 1; srv2-node0 = 1; }; address = getAddress "nas"; }
    { to = "pc"; from = { nas = 1; srv2-node0 = 1; }; address = getAddress "pc"; }
    # srv1 内部网络
    {
      to = "srv1-node0";
      from = { srv1-node1 = 1; srv1-node2 = 1; };
      address = "192.168.178.1";
      forwards =
      [
        { weight = 1; address = [ "nas" "pc" "srv2-node0" ]; }
        { weight = 2; address = [ "srv2-node1" ]; }
        { weight = 10; address = [ "vps6" ]; }
        { weight = 11; address = [ "vps4" ]; }
      ];
    }
    { to = "srv1-node1"; from = { srv1-node0 = 1; srv1-node2 = 1; }; address = "192.168.178.2"; }
    { to = "srv1-node2"; from = { srv1-node0 = 1; srv1-node1 = 1; }; address = "192.168.178.3"; }
    # srv2 内部网络
    {
      to = "srv2-node0";
      from.srv2-node1 = 1;
      address = "192.168.178.1";
      forwards =
      [
        { weight = 1; address = [ "nas" "pc" "srv1-node0" ]; }
        { weight = 2; address = [ "srv1-node1" "srv1-node2" ]; }
        { weight = 10; address = [ "vps6" ]; }
        { weight = 11; address = [ "vps4" ]; }
      ];
    }
    { to = "srv2-node1"; from.srv2-node0 = 1; address = "192.168.178.2"; }
    # 厦大内网
    {
      to = "srv1-node0";
      from = { nas = 1; pc = 1; srv2-node0 = 1; };
      address = getAddress "srv1-node0";
      forwards = [{ weight = 1; address = [ "srv1-node1" "srv1-node2" ]; }];
    }
    {
      to = "srv2-node0";
      from = { nas = 1; pc = 1; srv1-node0 = 1; };
      address = getAddress "srv2-node0";
      forwards = [{ weight = 1; address = [ "nas" "pc" "srv2-node1" ]; }];
    }
    # 公网服务器
    {
      to = "vps4";
      from = { nas = 10; vps6 = 1; };
      address = getAddress "vps4";
      forwards =
      [
        { weight = 1; address = [ "vps6" ]; }
        { weight = 10; address = [ "nas" ]; }
        { weight = 11; address = [ "pc" "srv1-node0" "srv2-node0" ]; }
        { weight = 12; address = [ "srv1-node1" "srv1-node2" "srv2-node1" ]; }
      ];
    }
    {
      to = "vps6";
      from = { pc = 10; vps4 = 1; srv1-node0 = 10; srv2-node0 = 10; };
      address = getAddress "vps6";
      forwards =
      [
        { weight = 1; address = [ "vps4" ]; }
        { weight = 10; address = [ "pc" "srv1-node0" "srv2-node0" ]; }
        { weight = 11; address = [ "nas" "srv1-node1" "srv1-node2" "srv2-node1" ]; }
      ];
    }
  ];
  nodesWithSettings = builtins.map
    (node: node // { settings =
    {
      addresses = [{ inherit (node) address; }];
      settings.Ed25519PublicKey = publicKey.${node.to};
      subnets = builtins.concatLists
      [
        (builtins.concatLists (builtins.map
          (forward: builtins.map
            (destNode: { address = getAddress "tinc0.${destNode}"; inherit (forward) weight; })
            forward.address)
          (node.forwards or [])))
        [{ address = getAddress "tinc0.${node.to}"; weight = 0; }]
      ];
    };})
    nodes;
in
{
  config = inputs.lib.mkIf (builtins.hasAttr hostname publicKey)
  {
    services.tinc.networks.tinc0 = 
    {
      settings = { Interface = "tinc0"; Name = builtins.replaceStrings [ "-" ] [ "_" ] hostname; PingInterval = 10; };
      ed25519PrivateKeyFile = inputs.config.nixos.system.sops.secrets."tinc".path;
      hostSettings = inputs.lib.mkMerge
      [
        # 本机
        {
          "${hostname}" =
          {
            settings.Ed25519PublicKey = publicKey.${hostname};
            subnets = [{ address = getAddress "tinc0.${hostname}"; weight = 0; }];
          };
        }
        (inputs.lib.mkMerge (builtins.map
          (node:
            # 如果描述的是到本机的连接，给 from 中的机器加上信息，只用加它们的公钥和ip即可
            if node.to == hostname then inputs.lib.mkMerge (builtins.map
              (fromNode:
              {
                "${fromNode}" =
                {
                  settings.Ed25519PublicKey = publicKey.${fromNode};
                  subnets = [{ address = getAddress "tinc0.${fromNode}"; weight = node.from.${fromNode}; }];
                };
              })
              (builtins.attrNames node.from))
            # 如果描述的是来自本机的连接，使用已经生成的设置，并加上权重的偏移
            else if builtins.hasAttr hostname node.from then
            {
              "${node.to}" =
              {
                inherit (node.settings) addresses settings;
                subnets = builtins.map
                  (subnet: { inherit (subnet) address; weight = subnet.weight + node.from.${hostname}; })
                  node.settings.subnets;
              };
            }
            else {})
          nodesWithSettings))
      ];
    };
    nixos.system =
    {
      sops.secrets."tinc".owner = "tinc-tinc0";
      network.settings = inputs.lib.mkIf (inputs.config.nixos.system.network.implementation == "systemd-networkd")
        { static."tinc0" = { ip = getAddress "tinc0.${hostname}"; mask = 24; }; };
    };
    environment.etc = inputs.lib.mkIf (inputs.config.nixos.system.network.implementation == "networkmanager")
    {
      "tinc/tinc0/tinc-up".source = inputs.pkgs.writeShellScript "tinc-up"
      ''
        ${inputs.pkgs.iproute2}/bin/ip link set $INTERFACE up
        ${inputs.pkgs.iproute2}/bin/ip addr add ${getAddress "tinc0.${hostname}"}/24 dev $INTERFACE
      '';
    };
    networking.firewall = { allowedTCPPorts = [ 655 ]; allowedUDPPorts = [ 655 ]; trustedInterfaces = [ "tinc0" ]; };
  };
}
