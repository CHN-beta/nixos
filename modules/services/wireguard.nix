inputs:
{
  options.nixos.services.wireguard = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
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
      default = if inputs.config.nixos.services.wireguard.behindNat then 51821 else 51820;
    };
    wireguardIp = mkOption { type = types.nonEmptyStr; };
    peers = mkOption { type = types.nonEmptyListOf types.nonEmptyStr; default = []; };
  };
  config =
    let
      inherit (inputs.lib) mkIf mkMerge;
      inherit (inputs.config.nixos.services) wireguard;
      inherit (builtins) map toString listToAttrs filter;
    in mkMerge
    [
      {
        assertions =
        [{
          assertion = !wireguard.behindNat -> wireguard.listenIp != null;
          message = "wireguard.listenIp should be not null when behindNat is false.";
        }];
      }
      (
        mkIf wireguard.enable
        {
          networking =
          {
            firewall = { allowedUDPPorts = [ wireguard.listenPort ]; trustedInterfaces = [ "wireguard" ]; };
            wireguard.interfaces.wireguard =
            {
              ips = [ "${wireguard.wireguardIp}/24" ];
              inherit (wireguard) listenPort;
              privateKeyFile = inputs.config.sops.secrets."wireguard/privateKey".path;
              peers = map
                (peer:
                {
                  publicKey = peer.publicKey;
                  allowedIPs = [ (if peer.lighthouse then "192.168.83.0/24" else "${peer.wireguardIp}/32") ];
                  endpoint = mkIf (!peer.behindNat) "${peer.listenIp}:${builtins.toString peer.listenPort}";
                  persistentKeepalive = mkIf peer.lighthouse 5;
                })
                (map
                  (peer: inputs.topInputs.self.nixosConfigurations.${peer}.config.nixos.services.wireguard)
                  wireguard.peers);
            };
          };
          sops.secrets."wireguard/privateKey" = {};
          # somehow fix wireguard connection
          systemd.services = mkIf wireguard.behindNat (listToAttrs (map
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
            (filter (peer: !peer.value.behindNat) (map
              (peer:
              {
                name = peer;
                value = inputs.topInputs.self.nixosConfigurations.${peer}.config.nixos.services.wireguard;
              })
              wireguard.peers))));
        }
      )
    ];
}
