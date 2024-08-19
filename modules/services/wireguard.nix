inputs:
{
  options.nixos.services.wireguard = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule (submoduleInputs: { options =
    {
      # wg genkey | wg pubkey
      publicKey = mkOption { type = types.nonEmptyStr; };
      lighthouse = mkOption { type = types.bool; default = false; };
      behindNat = mkOption
      {
        type = types.bool;
        default = inputs.config.nixos.services.xray.client.enable;
      };
      listenIp = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
      # if the host is behind xray, it should listen on another port, to make xray succeffully listen on 51820
      listenPort = mkOption
      {
        type = types.ints.unsigned;
        default = if submoduleInputs.config.behindNat then 51821 else 51820;
      };
      wireguardIp = mkOption { type = types.nonEmptyStr; };
      peers = mkOption { type = types.nonEmptyListOf types.nonEmptyStr; default = []; };
    };}));
    default = null;
  };
  config =
    let inherit (inputs.config.nixos.services) wireguard;
    in inputs.lib.mkIf (wireguard != null) (inputs.lib.mkMerge
    [
      {
        assertions =
        [{
          assertion = !wireguard.behindNat -> wireguard.listenIp != null;
          message = "wireguard.listenIp should be not null when behindNat is false.";
        }];
      }
      {
        networking =
        {
          firewall =
          {
            allowedUDPPorts = inputs.lib.mkIf (!wireguard.behindNat) [ wireguard.listenPort ];
            trustedInterfaces = [ "wireguard" ];
          };
          wireguard.interfaces.wireguard =
          {
            ips = [ "${wireguard.wireguardIp}/24" ];
            inherit (wireguard) listenPort;
            privateKeyFile = inputs.config.sops.secrets."wireguard/privateKey".path;
            peers = builtins.map
              (peer:
              {
                publicKey = peer.publicKey;
                allowedIPs = [ (if peer.lighthouse then "192.168.83.0/24" else "${peer.wireguardIp}/32") ];
                endpoint = inputs.lib.mkIf (!peer.behindNat) "${peer.listenIp}:${builtins.toString peer.listenPort}";
                persistentKeepalive = inputs.lib.mkIf peer.lighthouse 5;
              })
              (builtins.map
                (peer: (inputs.localLib.getConfig inputs peer "wireguard").nixos.services.wireguard)
                wireguard.peers);
          };
        };
        sops.secrets."wireguard/privateKey" = {};
        # somehow fix wireguard connection
        systemd.services = inputs.lib.mkIf wireguard.behindNat (builtins.listToAttrs (builtins.map
          (peer:
          {
            name = "wireguard-ping-${peer.name}";
            value =
            {
              description = "ping ${peer.name}";
              after = [ "network.target" ];
              wantedBy = [ "multi-user.target" ];
              serviceConfig =
              {
                ExecStart = "${inputs.pkgs.iputils}/bin/ping -i 5 ${peer.value.wireguardIp}";
                Restart = "always";
              };
            };
          })
          (builtins.filter (peer: !peer.value.behindNat) (map
            (peer:
            {
              name = peer;
              value = (inputs.localLib.getConfig inputs peer "wireguard").nixos.services.wireguard;
            })
            wireguard.peers))));
      }
    ]);
}
