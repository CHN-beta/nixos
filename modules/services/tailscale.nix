inputs:
{
  options.nixos.services.tailscale = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = {}; };
  config =
    let inherit (inputs.config.nixos.services) tailscale;
    in inputs.lib.mkIf (tailscale != null) (inputs.lib.mkMerge
    [
      {
        services.tailscale =
        {
          enable = true;
          openFirewall = true;
          disableTaildrop = true;
          # authKeyParameters should not be set
          authKeyFile = inputs.config.nixos.system.sops.secrets."tailscale".path;
          extraUpFlags = [ "--login-server=https://headscale.chn.moe" "--accept-dns=false" ];
          extraSetFlags = [ "--accept-dns=false" ];
        };
        nixos.system.sops.secrets."tailscale" = {};
        networking.firewall.trustedInterfaces = [ inputs.config.services.tailscale.interfaceName ];
      }
      # 如果启用了 xray client，则 dns 交给 dnsmasq 处理
      # 如果没有启用 xray client 但使用 systemd networkd，则 dns 交给 systemd-networkd 处理
      # 否则，需要交给 networkmanager 处理，但暂时不用实现
      (
        inputs.localLib.mkConditional (inputs.config.nixos.services.xray.client != null)
          { services.dnsmasq.settings.server = [ "/ts.chn.moe/100.100.100.100" ]; }
          (
            inputs.localLib.mkConditional (inputs.config.nixos.system.network.implementation == "systemd-networkd")
              {
                services.resolved.extraConfig =
                ''
                  [Resolve]
                  DNS=100.100.100.100
                  Domains=~ts.chn.moe
                '';
              }
              { assertions = [{ assertion = false; message = "not implemented"; }]; }
          )
      )
    ]);
}
