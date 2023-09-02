inputs:
{
  options.nixos.system.initrd = let inherit (inputs.lib) mkOption types; in
  {
    network.enable = mkOption { type = types.bool; default = false; };
    sshd =
    {
      enable = mkOption { type = types.bool; default = false; };
      hostKeys = mkOption { type = types.listOf types.nonEmptyStr; default = []; };
    };
  };
  config =
    let
      inherit (inputs.config.nixos.system) initrd;
    in { boot =
    {
      initrd =
      {
        systemd.enable = true;
        network =
        {
          enable = initrd.network.enable;
          ssh = { enable = true; hostKeys = initrd.sshd.hostKeys; };
        };
      };
      kernelParams = if initrd.network.enable then [ "ip=dhcp" ] else [];
    };};
}
