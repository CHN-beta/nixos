inputs:
{
  options.nixos.services.nebula = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
    # null: is lighthouse, non-empty string: is not lighthouse, and use this string as lighthouse address.
    lighthouse = mkOption { type = types.nullOr types.nonEmptyStr; default = null; };
  };
  config =
    let
      inherit (inputs.lib) mkIf;
      inherit (inputs.config.nixos.services) nebula;
      inherit (builtins) concatStringsSep;
    in mkIf nebula.enable
    {
      services.nebula.networks.nebula =
      {
        enable = true;
        ca = ./ca.crt;
        cert = ./. + "/${inputs.config.nixos.system.hostname}.crt";
        key = inputs.config.sops.templates."nebula/key-template".path;
        firewall.inbound = [ { host = "any"; port = "any"; proto = "any"; } ];
        firewall.outbound = [ { host = "any"; port = "any"; proto = "any"; } ];
      }
      // (
        if nebula.lighthouse == null then { isLighthouse = true; }
        else
        {
          lighthouses = [ "192.168.82.1" ];
          staticHostMap."192.168.82.1" = [ "${nebula.lighthouse}:4242" ];
          listen.port = 0;
        }
      );
      sops =
      {
        templates."nebula/key-template" =
        {
          content = concatStringsSep "\n"
          [
            "-----BEGIN NEBULA X25519 PRIVATE KEY-----"
            inputs.config.sops.placeholder."nebula/key"
            "-----END NEBULA X25519 PRIVATE KEY-----"
          ];
          owner = inputs.config.systemd.services."nebula@nebula".serviceConfig.User;
          group = inputs.config.systemd.services."nebula@nebula".serviceConfig.Group;
        };
        secrets."nebula/key" = {};
      };
      networking.firewall = if nebula.lighthouse != null then {} else
      {
        allowedTCPPorts = [ 4242 ];
        allowedUDPPorts = [ 4242 ];
      };
    };
}
