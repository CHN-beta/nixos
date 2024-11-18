inputs:
{
  options.nixos.system.initrd = let inherit (inputs.lib) mkOption types; in
  {
    sshd = mkOption { type = types.nullOr (types.submodule {}); default = null; };
    unl0kr = mkOption { type = types.nullOr (types.submodule {}); default = null; };
    mumlock = mkOption { type = types.nullOr (types.submodule {}); default = {}; };
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
      inputs.lib.mkIf (initrd.sshd != null)
      {
        boot =
        {
          initrd =
          {
            network =
            {
              enable = true;
              ssh = { enable = true; hostKeys = [ "/nix/persistent/etc/ssh/initrd_ssh_host_ed25519_key" ]; };
            };
            # resolved does not work in initrd, causing network.target to fail
            services.resolved.enable = false;
          };
          # do not use ip=xxx, as it will override systemd-networkd configurations
          # kernelParams = [ "ip=on" ];
        };
      }
    )
    (inputs.lib.mkIf (initrd.unl0kr != null) { boot.initrd.unl0kr.enable = true; })
    (inputs.lib.mkIf (initrd.mumlock != null) { boot.initrd =
    {
      systemd.extraBin.setleds = "${inputs.pkgs.kbd}/bin/setleds";
      preDeviceCommands = "for tty in /dev/tty[1-6]; do setleds -D +num < $tty; done";
    };})
  ];
}
