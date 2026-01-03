inputs:
{
  config =
  {
    # only preserve the last 7 days of logs
    services =
    {
      journald.extraConfig = "MaxRetentionSec=7d";
      logind.settings.Login.HandleLidSwitch = "ignore";
    };
    systemd =
    {
      settings.Manager =
      {
        DefaultTimeoutStopSec = "10s";
        DefaultLimitNOFILE = "1048576:1048576";
      };
      user.extraConfig = "DefaultTimeoutStopSec=10s";
      services =
      {
        # do not create /var/lib/machines and /var/lib/portables as subvolumes
        systemd-tmpfiles-setup.environment.SYSTEMD_TMPFILES_FORCE_SUBVOL = "0";
        # useless
        systemd-machine-id-commit.enable = false;
      };
      # do not clean /tmp
      timers.systemd-tmpfiles-clean.enable = false;
      coredump = { enable = true; extraConfig = "Storage=none"; };
      # seems useless
      shutdownRamfs.enable = false;
    };
  };
}
