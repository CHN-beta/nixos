inputs:
{
  options.nixos.system.initrd = let inherit (inputs.lib) mkOption types; in
  {
    sshd =
    {
      enable = mkOption { type = types.bool; default = false; };
      hostKeys = mkOption
      {
        type = types.listOf types.nonEmptyStr;
        default = [ "/nix/persistent/etc/ssh/initrd_ssh_host_ed25519_key" ];
      };
    };
  };
  config =
    let
      inherit (inputs.config.nixos.system) initrd;
      inherit (inputs.lib) mkIf mkMerge;
    in mkMerge
    [
      { boot.initrd.systemd.enable = true; }
      (
        mkIf (initrd.sshd.enable)
        {
          boot =
          {
            initrd.network = { enable = true; ssh = { enable = true; hostKeys = initrd.sshd.hostKeys; }; };
            kernelParams = [ "ip=dhcp,auto6" ];
          };
        }
      )
    ];
}
