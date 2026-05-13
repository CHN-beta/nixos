{ localLib, config, lib, pkgs, self, ... }:
{
  imports = localLib.findModules ./.;
  options.system.build.archive = lib.mkOption
  {
    type = lib.types.package;
    readOnly = true;
    default = pkgs.closureInfo { rootPaths = [ config.system.build.toplevel.drvPath ]; };
  };
  config =
  {
    services =
    {
      dbus.implementation = "broker";
      acpid.enable = true;
      # TODO: set ipfs as separate service
      # kubo = { enable = true; autoMount = true; };
      # fstrim is enabled by default, disable it
      fstrim.enable = false;
      upower.enable = true;
      power-profiles-daemon.enable = true;
      gvfs.enable = true;
    };
    time.timeZone = "Asia/Shanghai";
    boot =
    {
      supportedFilesystems = [ "ntfs" "nfs" "nfsv4" ];
      # consoleLogLevel = 7;
    };
    hardware =
      { enableAllFirmware = true; bluetooth.enable = true; sensor.iio.enable = true; i2c.enable = true; };
    environment =
    {
      sessionVariables = rec
      {
        XDG_CACHE_HOME = "$HOME/.cache";
        XDG_CONFIG_HOME = "$HOME/.config";
        XDG_DATA_HOME = "$HOME/.local/share";
        XDG_STATE_HOME = "$HOME/.local/state";
        # do not set ANDROID_HOME, since some adb tools does not respect it
        # ANDROID_HOME = "${XDG_DATA_HOME}/android";
        # do not export HISTFILE
        # when HISTFILE is export but HISTSIZE is set but not export, in sub shell,
        #   HISTFILE will persist but HISTSIZE will not, make history file be overwritten
        # HISTFILE= "${XDG_STATE_HOME}/bash/history";
        CUDA_CACHE_PATH = "${XDG_CACHE_HOME}/nv";
        GNUPGHOME = "${XDG_DATA_HOME}/gnupg";
        GTK2_RC_FILES = "${XDG_CONFIG_HOME}/gtk-2.0/gtkrc";
        XCOMPOSECACHE = "${XDG_CACHE_HOME}/X11/xcompose";
        MATHEMATICA_USERBASE = "${XDG_CONFIG_HOME}/mathematica";
        _JAVA_OPTIONS = "-Djava.util.prefs.userRoot=${XDG_CONFIG_HOME}/java";
        # it is safe to always enable this, only effective when using wayland
        NIXOS_OZONE_WL = "1";
      };
      variables =
      {
        NIXOS_CONFIGURATION_REVISION = config.system.configurationRevision;
        # CPATH = "/run/current-system/sw/include";
        # LIBRARY_PATH = "/run/current-system/sw/lib";
      };
      # pathsToLink = [ "/include" ];
    };
    i18n = { defaultLocale = "C.UTF-8"; supportedLocales = [ "all" ]; };
    users.mutableUsers = false;
    virtualisation.oci-containers.backend = "podman";
    home-manager.sharedModules = [{ home.stateVersion = "25.05"; }];
    system =
    {
      stateVersion = "25.05";
      configurationRevision = self.rev or "dirty";
      nixos =
      {
        versionSuffix = lib.mkForce "";
        tags = [ (builtins.substring 2 6 self.lastModifiedDate) (builtins.substring 0 6 self.rev or "dirty") ];
      };
    };
    programs.criu.enable = true;
  };
}
