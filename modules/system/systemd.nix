inputs: { config =
{
  # only preserve the last 7 days of logs
  services.journald.extraConfig = "MaxRetentionSec=7d";
  systemd =
  {
    extraConfig =
    ''
      DefaultTimeoutStopSec=10s
      DefaultLimitNOFILE=1048576:1048576
    '';
    user.extraConfig = "DefaultTimeoutStopSec=10s";
    # do not create /var/lib/machines and /var/lib/portables as subvolumes
    services.systemd-tmpfiles-setup.environment.SYSTEMD_TMPFILES_FORCE_SUBVOL = "0";
    # do not clean /tmp
    timers.systemd-tmpfiles-clean.enable = false;
    coredump = { enable = true; extraConfig = "Storage=none"; };
  };
};}
