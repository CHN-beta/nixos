inputs:
{
  options.nixos.services.wireguard = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.attrsOf (types.submodule (submoduleInputs: { options =
      let generalOption =
      {
        publicKey = mkOption { type = types.nonEmptyStr; };
        lighthouse = mkOption { type = types.bool; default = false; };
        # if behind nat, set to null; if not, set to the public ip
        listenIp = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
        # if specify "3", then the subnet should be 192.168.83.3/24
        wireguardIp = mkOption { type = types.int; };
      };
      in generalOption
        // {
          # if listenIp is set, actually listen on this port; otherwise, listen on this port + behindNatPortOffset
          listenPort = mkOption { type = types.int; };
          # if specify "83", then the subnet should be 192.168.83.0/24
          net = mkOption { type = types.int; };
          behindNatPortOffset = mkOption { type = types.int; default = 1; readOnly = true; };
          peers = mkOption { type = types.nonEmptyListOf (types.submodule { options = generalOption; }); };
        };
    }));
    default = {};
  };
  config = let inherit (inputs.config.nixos.services) wireguard; in inputs.lib.mkIf (wireguard != {})
  {
    assertions = builtins.map
      (wg:
      {
        assertion = inputs.config.nixos.services.xray.client.enable -> (wg.value.listenIp == null);
        message = "Wireguard should behind NAT when xray client is enabled.";
      })
      (inputs.localLib.attrsToList wireguard);
    networking = inputs.lib.mkMerge (builtins.map
      (wg:
      {
        firewall =
        {
          allowedUDPPorts = inputs.lib.mkIf (wg.value.listenIp != null) [ wg.value.listenPort ];
          trustedInterfaces = [ wg.name ];
        };
        wireguard.interfaces.${wg.name} =
        {
          ips = [ "192.168.${builtins.toString wg.value.net}.${builtins.toString wg.value.wireguardIp}/24" ];
          # if the host is behind xray, it should listen on another port, to make xray succeffully listen on 51820
          listenPort = with wg.value; if listenIp == null then listenPort + behindNatPortOffset else listenPort;
          privateKeyFile = inputs.config.sops.secrets."wireguard/${wg.name}".path;
          peers = builtins.map
            (peer:
            {
              inherit (peer) publicKey;
              allowedIPs = let suffix = if peer.lighthouse then "0/24" else "${builtins.toString peer.wireguardIp}/32";
                in [ "192.168.${builtins.toString wg.value.net}.${suffix}" ];
              endpoint = inputs.lib.mkIf (peer.listenIp != null)
                "${peer.listenIp}:${builtins.toString wg.value.listenPort}";
              persistentKeepalive = inputs.lib.mkIf peer.lighthouse 1;
            })
            wg.value.peers;
        };
      })
      (inputs.localLib.attrsToList wireguard));
    sops.secrets = inputs.lib.mkMerge (builtins.map
      (wg: { "wireguard/${wg.name}" = {}; }) (inputs.localLib.attrsToList wireguard));    
  };
}
