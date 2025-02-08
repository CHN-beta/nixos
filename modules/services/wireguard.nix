inputs:
{
  options.nixos.services.wireguard = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule (submoduleInputs: { options =
      let generalOption =
      {
        publicKey = mkOption { type = types.nonEmptyStr; };
        lighthouse = mkOption { type = types.bool; default = false; };
        behindNat = mkOption { type = types.bool; default = false; };
        listenIp = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
        wireguardIp = mkOption { type = types.nonEmptyStr; };
      };
      in generalOption
        // { peers = mkOption { type = types.nonEmptyListOf (types.submodule { options = generalOption; }); }; };
    }));
    default = null;
  };
  config = let inherit (inputs.config.nixos.services) wireguard; in inputs.lib.mkIf (wireguard != null)
  {
    assertions =
    [
      {
        assertion = !wireguard.behindNat -> wireguard.listenIp != null;
        message = "wireguard.listenIp should not be null when behindNat is false.";
      }
      {
        assertion = inputs.config.nixos.services.xray.client.enable -> wireguard.behindNat;
        message = "Wireguard is behind NAT when xray client is enabled.";
      }
    ];
    networking =
    {
      firewall =
      {
        allowedUDPPorts = inputs.lib.mkIf (!wireguard.behindNat) [ 51820 ];
        trustedInterfaces = [ "wireguard" ];
      };
      wireguard.interfaces.wireguard =
      {
        ips = [ "${wireguard.wireguardIp}/24" ];
        # if the host is behind xray, it should listen on another port, to make xray succeffully listen on 51820
        listenPort = inputs.localLib.mkConditional wireguard.behindNat 51821 51820;
        privateKeyFile = inputs.config.sops.secrets."wireguard/privateKey".path;
        peers = builtins.map
          (peer:
          {
            inherit (peer) publicKey;
            allowedIPs = [ (if peer.lighthouse then "192.168.83.0/24" else "${peer.wireguardIp}/32") ];
            endpoint = inputs.lib.mkIf (!peer.behindNat) "${peer.listenIp}:51820";
            persistentKeepalive = inputs.lib.mkIf peer.lighthouse 5;
          })
          wireguard.peers;
      };
    };
    sops.secrets."wireguard/privateKey" = {};
  };
}
