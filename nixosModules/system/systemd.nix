{ config, ... }:
{
  config = {
    services = {
      # only preserve the last 7 days of logs
      journald.extraConfig = "MaxRetentionSec=7d";
      prometheus.exporters.node = {
        enable = true;
        enabledCollectors = [ "systemd" ];
      };
    };
    systemd = {
      settings.Manager = {
        DefaultTimeoutStopSec = "10s";
        DefaultLimitNOFILE = "1048576:1048576";
      };
      user.extraConfig = "DefaultTimeoutStopSec=10s";
      services = {
        # do not create /var/lib/machines and /var/lib/portables as subvolumes
        systemd-tmpfiles-setup.environment.SYSTEMD_TMPFILES_FORCE_SUBVOL = "0";
        # useless
        systemd-machine-id-commit.enable = false;
      };
      # do not clean /tmp
      timers.systemd-tmpfiles-clean.enable = false;
      coredump = {
        enable = true;
        settings.Coredump.Storage = "none";
      };
      # seems useless
      shutdownRamfs.enable = false;
    };
    # accroding to systemd document, machine-id should be confidiential,
    # although I doubt is it really a problem for sharing over the network
    environment.etc.machine-id.source = config.nixos.system.sops.templates.machineId.path;
    nixos.system.sops = {
      secrets.machineId = { };
      templates.machineId = {
        content = config.nixos.system.sops.placeholder.machineId + "\n";
        mode = "0444";
      };
    };
  };
}
