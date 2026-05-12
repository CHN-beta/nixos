inputs:
{
  options.nixos.services.fail2ban = let inherit (inputs.lib) mkOption types; in mkOption
    { type = types.nullOr (types.submodule {}); default = null; };
  config = let inherit (inputs.config.nixos.services) fail2ban; in inputs.lib.mkIf (fail2ban != null)
  {
    services.fail2ban = { enable = true; ignoreIP = [ "127.0.0.0/8" "192.168.0.0/16" "vps6.chn.moe" ]; };
  };
}
