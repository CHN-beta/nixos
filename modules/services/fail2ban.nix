inputs:
{
  options.nixos.services.fail2ban = let inherit (inputs.lib) mkOption types; in
  {
    enable = mkOption { type = types.bool; default = false; };
  };
  config =
    let
      inherit (inputs.config.nixos.services) fail2ban;
      inherit (inputs.lib) mkIf;
    in mkIf fail2ban.enable
    {
      services.fail2ban =
      {
        enable = true;
        ignoreIP = [ "127.0.0.0/8" "192.168.0.0/16" "vps6.chn.moe" ];
      };
    };
}
