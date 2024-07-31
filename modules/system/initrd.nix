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
    unl0kr = mkOption { type = types.nullOr (types.submodule {}); default = null; };
  };
  config = let inherit (inputs.config.nixos.system) initrd; in inputs.lib.mkMerge
  [
    {
      boot =
      {
        initrd.systemd.enable = true;
        kernelParams = [ "boot.shell_on_fail" "systemd.setenv=SYSTEMD_SULOGIN_FORCE=1" ];
      };
    }
    (
      inputs.lib.mkIf (initrd.sshd.enable)
      {
        boot =
        {
          initrd =
          {
            network = { enable = true; ssh = { enable = true; hostKeys = initrd.sshd.hostKeys; }; };
            # resolved does not work in initrd, causing network.target to fail
            services.resolved.enable = false;
          };
          kernelParams = [ "ip=dhcp" ];
        };
      }
    )
    (inputs.lib.mkIf (initrd.unl0kr != null) { boot.initrd.unl0kr.enable = true; })
  ];
}
