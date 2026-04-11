inputs:
{
  options.nixos.services.tailscale = let inherit (inputs.lib) mkOption types; in mkOption
  {
    type = types.nullOr (types.submodule {});
    default = if inputs.config.nixos.model.arch == "x86_64" then {} else null;
  };
  config = let inherit (inputs.config.nixos.services) tailscale; in inputs.lib.mkIf (tailscale != null)
  {
    services.tailscale =
    {
      enable = true;
      openFirewall = true;
      disableTaildrop = true;
      # authKeyParameters should not be set
      authKeyFile = inputs.config.nixos.system.sops.secrets."tailscale".path;
      extraUpFlags = [ "--login-server=https://headscale.chn.moe" "--accept-dns=false" "--netfilter-mode=off" ];
      extraSetFlags = [ "--accept-dns=false" "--netfilter-mode=off" ];
    };
    nixos.system.sops.secrets."tailscale" = {};
    networking.firewall.trustedInterfaces = [ inputs.config.services.tailscale.interfaceName ];
    users =
    {
      users.tailscale = { uid = inputs.config.nixos.user.uid.tailscale; group = "tailscale"; isSystemUser = true; };
      groups.tailscale.gid = inputs.config.nixos.user.gid.tailscale;
    };
    systemd.services.tailscaled.serviceConfig =
    {
      User = "tailscale";
      Group = "tailscale";
      AmbientCapabilities = [ "CAP_NET_RAW" "CAP_NET_ADMIN" "CAP_SYS_MODULE" ];
      # without this, tailscale may think tinc is local address and use it
      RestrictNetworkInterfaces = "~tinc0";
    };
  };
}
