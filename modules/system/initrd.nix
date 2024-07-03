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
  config = let inherit (inputs.config.nixos.system) initrd; in inputs.lib.mkMerge
  [
    { boot.initrd.systemd.enable = true; }
    (
      inputs.lib.mkIf (initrd.sshd.enable)
      {
        boot =
        {
          initrd.network = { enable = true; ssh = { enable = true; hostKeys = initrd.sshd.hostKeys; }; };
          kernelParams = [ "ip=dhcp" "boot.shell_on_fail" "systemd.setenv=SYSTEMD_SULOGIN_FORCE=1" ];
        };
      }
    )
  ];
}
