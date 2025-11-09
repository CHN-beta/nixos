inputs:
{
  options.nixos.services.tailscale = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = {}; };
  config = let inherit (inputs.config.nixos.services) tailscale; in inputs.lib.mkIf (tailscale != null)
  {
    services.tailscale =
    {
      enable = true;
      openFirewall = true;
      disableTaildrop = true;
      # authKeyParameters should not be set
      authKeyFile = inputs.config.nixos.system.sops.secrets."tailscale".path;
      extraUpFlags = [ "--login-server=https://headscale.chn.moe" "--accept-dns=false" ];
    };
    nixos.system.sops.secrets."tailscale" = {};
    networking.firewall.trustedInterfaces = [ inputs.config.services.tailscale.interfaceName ];
  };
}
