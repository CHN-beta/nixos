inputs:
{
  imports = inputs.localLib.findModules ./.;
  config =
  {
    services =
    {
      dbus.implementation = "broker";
      fstrim.enable = true;
      acpid.enable = true;
      # TODO: set ipfs as separate service
      # kubo = { enable = true; autoMount = true; };
    };
    time.timeZone = "Asia/Shanghai";
    boot =
    {
      supportedFilesystems = [ "ntfs" "nfs" ];
      # consoleLogLevel = 7;
    };
    hardware.enableAllFirmware = true;
    environment =
    {
      sessionVariables = rec
      {
        XDG_CACHE_HOME = "$HOME/.cache";
        XDG_CONFIG_HOME = "$HOME/.config";
        XDG_DATA_HOME = "$HOME/.local/share";
        XDG_STATE_HOME = "$HOME/.local/state";
        # ANDROID_HOME = "${XDG_DATA_HOME}/android";
        HISTFILE= "${XDG_STATE_HOME}/bash/history";
        CUDA_CACHE_PATH = "${XDG_CACHE_HOME}/nv";
        DOCKER_CONFIG = "${XDG_CONFIG_HOME}/docker";
        GNUPGHOME = "${XDG_DATA_HOME}/gnupg";
        GTK2_RC_FILES = "${XDG_CONFIG_HOME}/gtk-2.0/gtkrc";
        XCOMPOSECACHE = "${XDG_CACHE_HOME}/X11/xcompose";
        MATHEMATICA_USERBASE = "${XDG_CONFIG_HOME}/mathematica";
        _JAVA_OPTIONS = "-Djava.util.prefs.userRoot=${XDG_CONFIG_HOME}/java";
      };
      variables =
      {
        NIXOS_CONFIGURATION_REVISION = inputs.config.system.configurationRevision;
        # CPATH = "/run/current-system/sw/include";
        # LIBRARY_PATH = "/run/current-system/sw/lib";
      };
      # pathsToLink = [ "/include" ];
    };
    i18n = { defaultLocale = "C.UTF-8"; supportedLocales = [ "all" ]; };
    users.mutableUsers = false;
    virtualisation.oci-containers.backend = "docker";
    home-manager.sharedModules = [{ home.stateVersion = "22.11"; }];
    system =
    {
      stateVersion = "22.11";
      configurationRevision = inputs.topInputs.self.rev or "dirty";
      nixos = { versionSuffix = inputs.lib.mkForce ""; tags = [ inputs.topInputs.self.config.branch ]; };
    };
    chaotic.nyx.cache.enable = false;
  };
}
