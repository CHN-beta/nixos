inputs:
{
  options.nixos.services.wireguard = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.attrsOf (types.submodule (submoduleInputs: { options =
    {
      # wireguard 接口的 ip，不是 wireguard 监听的 ip（它实际上监听所有 ip）
      ip = mkOption { type = types.str; };
      # wireguard 接口的网段
      netmask = mkOption { type = types.int; default = 24; };
      # 设置 wireguard 监听的端口，如果不设置则随机，同时不开放防火墙
      listenPort = mkOption { type = types.nullOr types.int; default = null; };
      peer = mkOption { type = types.attrsOf (types.submodule { options =
      {
        publicKey = mkOption { type = types.nonEmptyStr; };
        endpoint = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
        allowedIPs = mkOption { type = types.nonEmptyListOf types.nonEmptyStr; };
      };});};
    };}));
    default = {};
  };
  config = let inherit (inputs.config.nixos.services) wireguard; in inputs.lib.mkIf (wireguard != {})
  {
    networking = inputs.lib.mkMerge (builtins.map
      (wg:
      {
        firewall =
        {
          allowedUDPPorts = inputs.lib.mkIf (wg.value.listenPort != null) [ wg.value.listenPort ];
          trustedInterfaces = [ wg.name ];
        };
        wireguard.interfaces.${wg.name} =
        {
          inherit (wg.value) listenPort;
          ips = [ "${wg.value.ip}/${builtins.toString wg.value.netmask}" ];
          privateKeyFile = inputs.config.sops.secrets.wireguard.path;
          peers = builtins.map
            (peer:
            {
              inherit (peer) name;
              inherit (peer.value) publicKey allowedIPs endpoint;
              persistentKeepalive = if peer.value.endpoint != null then 10 else null;
            })
            (inputs.localLib.attrsToList wg.value.peer);
          dynamicEndpointRefreshSeconds = 60;
        };
      })
      (inputs.localLib.attrsToList wireguard));
    sops.secrets.wireguard = {};
  };
}
